<!-- Docker Hub short description (max 100 chars):
PHP 8.5 CLI, Alpine: PDO MySQL/Postgres, gd, intl, pcntl. -prod and Xdebug -dev tags. amd64/arm64
-->
# treehousetim/php-cli-pdo

PHP CLI on Alpine Linux with PDO for MySQL and PostgreSQL, a broad extension
set, and hardened production defaults. Use it for cron jobs, queue workers,
scripts and CI. It pairs with
[`treehousetim/php-fpm-pdo`](https://hub.docker.com/r/treehousetim/php-fpm-pdo):
same PHP build, same extensions, same ini.

Multi-arch: `linux/amd64` (Intel/AMD) and `linux/arm64` (Apple Silicon, Graviton,
64-bit Raspberry Pi). `docker pull` picks the right one.

## Tags

| Tag                                  | Flavor | Use for                          |
|--------------------------------------|--------|----------------------------------|
| `8.5.13-prod`, `8.5-prod`            | prod   | production, staging, CI          |
| `8.5.13`, `8.5`, `latest`            | prod   | aliases of `-prod`               |
| `8.5.13-dev`, `8.5-dev`              | dev    | local development only           |

**A tag without `-dev` is always the production image.** Pin `8.5` to get PHP
patch releases automatically, or `8.5.13` to stay put.

## prod vs dev

|                       | prod                              | dev                                         |
|-----------------------|-----------------------------------|---------------------------------------------|
| php.ini               | `php.ini-production` + hardening  | `php.ini-development` + hardening           |
| display_errors        | Off (errors are logged)           | On, `E_ALL` including deprecations          |
| Xdebug                | —                                 | `start_with_request=trigger`, port **9004**, `host.docker.internal` |
| Composer              | — (deploy with `vendor/`)         | Composer 2                                  |

Xdebug uses port 9004 here (9003 in the FPM image), so you can debug a web
request and a CLI script side by side.

## Extensions

Everything in `php-fpm-pdo` (bcmath, bz2, calendar, curl, gd, gettext, gmp,
intl, mbstring, mysqli, opcache, pdo_mysql, pdo_pgsql, pdo_sqlite, sodium,
sqlite3, zip, …) **plus pcntl** for signal handling in long-running workers.

Not included, to keep attack surface down: exif, ffi, ftp, shmop, soap,
sockets, sysv*, xsl.

## Production defaults

Same hardening as the FPM image: `expose_php` off, errors logged not shown,
256M `memory_limit` (CLI), strict/secure session cookies, `date.timezone`
America/Chicago. Unlike FPM, `exec()` and friends are **enabled**, so scripts and
cron jobs can shell out. CLI has no execution time limit.

## Usage

```sh
# run a script
docker run --rm -v "$PWD":/app -w /app treehousetim/php-cli-pdo:8.5 php bin/job.php

# composer install (dev image)
docker run --rm -v "$PWD":/app -w /app treehousetim/php-cli-pdo:8.5-dev composer install

# debug a CLI script with Xdebug (IDE listening on 9004)
docker run --rm -v "$PWD":/app -w /app -e XDEBUG_TRIGGER=1 treehousetim/php-cli-pdo:8.5-dev php bin/job.php
```

## Notes

- Alpine uses musl rather than glibc. A few things differ from Debian/Ubuntu,
  e.g. `iconv('UTF-8', 'ASCII//TRANSLIT', 'Café')` returns `Caf'e`, not `Cafe`.

## Older tags

`8.3`, `8.2`, `8.1`, `8.0`, `7.0`, `7.2.1` and `7-latest` are earlier builds with a
different extension set. They're unmaintained and receive no security updates.
`8.1` and older are amd64-only.
