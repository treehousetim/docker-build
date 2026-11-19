<!-- Docker Hub short description (max 100 chars):
PHP 8.5 FPM, Alpine: PDO MySQL/Postgres, gd, intl, opcache. -prod and Xdebug -dev tags. amd64/arm64
-->
# treehousetim/php-fpm-pdo

PHP-FPM on Alpine Linux with PDO for MySQL and PostgreSQL, a broad extension
set, and hardened production defaults. Every release comes in two flavors:
**prod** for servers, **dev** for local development with Xdebug.

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

Check which flavor an image is:

```sh
docker image inspect -f '{{index .Config.Labels "com.treehousetim.image.flavor"}}' treehousetim/php-fpm-pdo:8.5
```

## prod vs dev

|                       | prod                              | dev                                         |
|-----------------------|-----------------------------------|---------------------------------------------|
| php.ini               | `php.ini-production` + hardening  | `php.ini-development` + hardening           |
| display_errors        | Off (errors are logged)           | On, `E_ALL` including deprecations          |
| session.cookie_secure | 1                                 | 0 (so sessions work over http on localhost) |
| Xdebug                | —                                 | `start_with_request=trigger`, port **9003**, `host.docker.internal` |
| Composer              | — (deploy with `vendor/`)         | Composer 2                                  |

## Extensions

bcmath, bz2, calendar, ctype, curl, dom, fileinfo, gd (freetype, jpeg, webp),
gettext, gmp, iconv, intl, mbstring, mysqli, mysqlnd, opcache, openssl,
pdo_mysql, pdo_pgsql, pdo_sqlite, sodium, sqlite3, xml, xmlreader, xmlwriter,
zip, zlib, plus the PHP core set.

Not included, to keep attack surface down: exif, ffi, ftp, shmop, soap,
sockets, sysvmsg, sysvsem, sysvshm, xsl.

## Production defaults

- `expose_php` off, `allow_url_include` off, errors logged rather than shown
- `memory_limit` 128M for web requests (`PHP_FPM_MEMORY_LIMIT`), 256M for CLI, `upload_max_filesize` 100M, `post_max_size` 110M,
  `max_execution_time` 60s
- Session cookies: strict mode, HttpOnly, Secure, SameSite=Lax, cookies only
- `date.timezone` America/Chicago (override with your own ini in `conf.d/`)
- FPM workers can't shell out: `exec`, `shell_exec`, `system`, `passthru`,
  `proc_open`, `popen`, `pcntl_exec` and `show_source` are disabled
- Opcache on with stock settings; workdir `/opt/site` (owned by `www-data`); listens on `:9000`

## Server sizing

The FPM pool defaults target a **4 GB RAM, 2–4 vCPU server**, sized for the
worst case: 24 workers × 128M `memory_limit` = 3 GB, leaving ~1 GB for nginx and
the OS, so the pool can't run the server out of memory. Rule:
`PHP_FPM_MAX_CHILDREN × PHP_FPM_MEMORY_LIMIT` ≤ server RAM − ~1 GB. Size it
for your server with env vars, no rebuild needed:

| Server RAM | `PHP_FPM_MAX_CHILDREN` | `PHP_FPM_START_SERVERS` | `PHP_FPM_MIN_SPARE_SERVERS` | `PHP_FPM_MAX_SPARE_SERVERS` |
|-----------:|-----------------------:|------------------------:|----------------------------:|----------------------------:|
| 1 GB       | 4                      | 2                       | 1                           | 3                           |
| 2 GB       | 8                      | 2                       | 2                           | 4                           |
| **4 GB**   | **24** (default)       | **5**                   | **3**                       | **8**                       |
| 8 GB       | 56                     | 10                      | 6                           | 16                          |

Also `PHP_FPM_MAX_REQUESTS` (default 1000) and
`PHP_FPM_REQUEST_TERMINATE_TIMEOUT` (default `120s`). Halve the worker counts if
the database runs on the same server.

## Usage

```yaml
# compose.yaml
services:
  php:
    image: treehousetim/php-fpm-pdo:8.5        # production
    # image: treehousetim/php-fpm-pdo:8.5-dev  # local development
    volumes:
      - ./:/opt/site
    environment:
      PHP_FPM_MAX_CHILDREN: 20
  nginx:
    image: nginx:alpine
    # fastcgi_pass php:9000;
```

Xdebug (dev only): set your IDE to listen on port 9003, then trigger with the
`XDEBUG_TRIGGER` cookie/query parameter or a browser extension.

## Notes

- Alpine uses musl rather than glibc. A few things differ from Debian/Ubuntu,
  e.g. `iconv('UTF-8', 'ASCII//TRANSLIT', 'Café')` returns `Caf'e`, not `Cafe`.
- See also [`treehousetim/php-cli-pdo`](https://hub.docker.com/r/treehousetim/php-cli-pdo)
  for the matching CLI image (cron jobs, workers, scripts).

## Older tags

`8.3`, `8.2`, `8.1`, `8.0`, `7.0`, `7.2.1` and `7-latest` are earlier builds with a
different extension set. They're unmaintained and receive no security updates.
`8.1` and older are amd64-only.
