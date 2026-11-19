#!/usr/bin/env bash
# Smoke-test locally built images: PHP version, every expected module
# (per SAPI), prod ini overrides, prod/dev differences (xdebug, composer, display_errors), php-fpm config.
#   ./test.sh                   # everything
#   ./test.sh fpm-prod dev      # targets and/or groups (prod, dev)
set -euo pipefail
cd "$(dirname "$0")"

PHP_VERSION="${PHP_VERSION:-$(sed -n '/variable "PHP_VERSION"/,/}/s/.*default *= *"\(.*\)".*/\1/p' docker-bake.hcl)}"
REPO="${REPO:-treehousetim}"
(( $# )) || set -- prod dev
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    prod|dev) TARGETS+=("cli-$arg" "fpm-$arg") ;;
    *)        TARGETS+=("$arg") ;;
  esac
done

# Expected `php -m` (identical for CLI and FPM, except pcntl which is CLI-only).
PROD_MODULES=(bcmath bz2 calendar Core ctype curl date dom fileinfo filter gd
  gettext gmp hash iconv intl json lexbor libxml mbstring mysqli mysqlnd openssl pcre PDO
  pdo_mysql pdo_sqlite Phar posix random readline Reflection session SimpleXML
  sodium SPL sqlite3 standard tokenizer uri xml xmlreader
  xmlwriter zip zlib "Zend OPcache" pdo_pgsql)
# Deliberately left out (attack surface); fail if any come back.
FORBIDDEN_MODULES=(exif FFI ftp shmop soap sockets sysvmsg sysvsem sysvshm xsl)

fail=0
for target in "${TARGETS[@]}"; do
  variant="${target%%-*}"          # cli | fpm
  flavor="${target#*-}"            # prod | dev
  image="$REPO/php-$variant-pdo:$PHP_VERSION-$flavor"
  echo "==> $image"
  before=$fail
  run() { docker run --rm --entrypoint "$1" "$image" "${@:2}"; }

  version="$(run php -r 'echo PHP_VERSION;')"
  [[ "$version" == "$PHP_VERSION" ]] || { echo "  FAIL: PHP $version, expected $PHP_VERSION"; fail=$((fail+1)); }

  # Any warning on startup (e.g. "Module already loaded") shows up on stderr.
  if warnings="$(run php -v 2>&1 >/dev/null)" && [[ -n "$warnings" ]]; then
    echo "  FAIL: startup warnings:"; echo "$warnings" | sed 's/^/    /'; fail=$((fail+1))
  fi

  if [[ "$variant" == fpm ]]; then
    modules="$(run php-fpm -m)"
    grep -qx pcntl <<<"$modules" && { echo "  FAIL: pcntl loaded under FPM (should be CLI-only)"; fail=$((fail+1)); }
  else
    modules="$(run php -m)"
    grep -qx pcntl <<<"$modules" || { echo "  FAIL: missing extension pcntl"; fail=$((fail+1)); }
  fi
  for ext in "${PROD_MODULES[@]}"; do
    grep -qix "$ext" <<<"$modules" || { echo "  FAIL: missing extension $ext"; fail=$((fail+1)); }
  done
  for ext in "${FORBIDDEN_MODULES[@]}"; do
    grep -qix "$ext" <<<"$modules" && { echo "  FAIL: extension $ext should not be loaded"; fail=$((fail+1)); }
  done

  ini="$(run php -r 'foreach (["memory_limit","date.timezone","upload_max_filesize","post_max_size","expose_php","phar.readonly","zend.exception_ignore_args","allow_url_include"] as $k) echo "$k=", ini_get($k), "\n";')"
  for want in memory_limit=256M date.timezone=America/Chicago upload_max_filesize=100M post_max_size=110M expose_php= \
              phar.readonly=1 zend.exception_ignore_args=1 allow_url_include=; do
    grep -qx "$want" <<<"$ini" || { echo "  FAIL: expected $want, got: $(grep "^${want%%=*}=" <<<"$ini")"; fail=$((fail+1)); }
  done

  label="$(docker image inspect -f '{{index .Config.Labels "com.treehousetim.image.flavor"}}' "$image")"
  [[ "$label" == "$flavor" ]] || { echo "  FAIL: flavor label is '$label', expected $flavor"; fail=$((fail+1)); }

  display_errors="$(run php -r 'echo ini_get("display_errors");')"
  if [[ "$flavor" == dev ]]; then
    grep -qx xdebug <<<"$modules" || { echo "  FAIL: xdebug not loaded"; fail=$((fail+1)); }
  else
    grep -qx xdebug <<<"$modules" && { echo "  FAIL: xdebug present in prod image"; fail=$((fail+1)); }
    [[ -z "$display_errors" || "$display_errors" == 0 ]] || { echo "  FAIL: display_errors on in prod image"; fail=$((fail+1)); }
    # bare version tag must point at the prod image
    [[ "$(docker image inspect -f '{{.Id}}' "$REPO/php-$variant-pdo:$PHP_VERSION")" == "$(docker image inspect -f '{{.Id}}' "$image")" ]] \
      || { echo "  FAIL: :$PHP_VERSION is not the prod image"; fail=$((fail+1)); }
  fi

  if [[ "$flavor" == dev ]]; then
    run composer --version >/dev/null 2>&1 || { echo "  FAIL: composer"; fail=$((fail+1)); }
  else
    run sh -c 'command -v composer' >/dev/null && { echo "  FAIL: composer present in prod image (deploy with vendor/)"; fail=$((fail+1)); }
  fi

  if [[ "$variant" == fpm ]]; then
    fpmconf="$(run php-fpm -tt 2>&1)" || { echo "  FAIL: php-fpm -tt"; fail=$((fail+1)); }
    for want in "pm.max_children = 24" "pm.max_requests = 1000" "request_terminate_timeout = 120" "memory_limit.*128M"; do
      grep -q "$want" <<<"$fpmconf" || { echo "  FAIL: fpm pool missing '$want'"; fail=$((fail+1)); }
    done
    grep -q "disable_functions.*shell_exec" <<<"$fpmconf" || { echo "  FAIL: fpm pool doesn't disable exec functions"; fail=$((fail+1)); }
    # Must be absent, not empty: "ping.path =" kills every worker on 8.5.13+.
    for d in pm.status_path ping.path; do
      grep -qE "[[:space:]]$d = undefined$" <<<"$fpmconf" || { echo "  FAIL: $d is set (want unset): $(grep -E "[[:space:]]$d =" <<<"$fpmconf" | sed 's/.*NOTICE: *//')"; fail=$((fail+1)); }
    done
    fpminfo="$(run php-fpm -i)"
    grep -qE "^cgi.fix_pathinfo => (Off|0) " <<<"$fpminfo" || { echo "  FAIL: cgi.fix_pathinfo not 0 under fpm"; fail=$((fail+1)); }

    # -tt only parses config. Start FPM for real and serve one FastCGI request,
    # so a pool whose workers die on startup can't pass.
    cid="$(docker run -d -v "$PWD/tests:/opt/fcgitest:ro" "$image")"
    resp=""
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      resp="$(docker exec "$cid" php /opt/fcgitest/fcgi-request.php /opt/fcgitest/ok.php 2>&1)" && break
      sleep 0.5
    done
    grep -q "^fcgi-ok memory_limit=128M sapi=fpm-fcgi" <<<"$resp" \
      || { echo "  FAIL: php-fpm didn't serve a request: $resp"; fail=$((fail+1)); }
    if errs="$(docker logs "$cid" 2>&1 | grep -E "ERROR|exited with code")"; then
      echo "  FAIL: php-fpm logged errors:"; sed -n '1,5s/^/    /p' <<<"$errs"; fail=$((fail+1))
    fi
    docker rm -f "$cid" >/dev/null
  fi

  [[ $fail == "$before" ]] && echo "  ok: PHP $version ($flavor)"
done

exit $(( fail > 0 ))
