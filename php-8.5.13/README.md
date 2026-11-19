# treehousetim PHP 8.5 images

Alpine-based PHP CLI and FPM images with hardened production defaults:
a broad extension set, locked-down ini, and sized FPM pool. Every image
comes in two flavors.

## Tags: prod vs dev

| Tag                                     | Flavor | Use for                      |
|-----------------------------------------|--------|------------------------------|
| `php-fpm-pdo:8.5.13-prod`, `:8.5-prod`  | prod   | production, staging, CI      |
| `php-fpm-pdo:8.5.13`, `:8.5`, `:latest` | prod   | (alias of `-prod`)           |
| `php-fpm-pdo:8.5.13-dev`, `:8.5-dev`    | dev    | local development only       |

Same for `treehousetim/php-cli-pdo`. **A tag without `-dev` is always the prod
image.** `:latest` follows the newest PHP release (publish older branches with
`LATEST=false ./publish.sh`). Check an image you already have:

```sh
docker image inspect -f '{{index .Config.Labels "com.treehousetim.image.flavor"}}' treehousetim/php-fpm-pdo:8.5
```

|                        | prod                                       | dev                                    |
|------------------------|--------------------------------------------|----------------------------------------|
| php.ini base           | `php.ini-production`                       | `php.ini-development`                  |
| display_errors         | Off                                        | On, `E_ALL` (incl. deprecations)       |
| session.cookie_secure  | 1                                          | 0 (http on localhost)                  |
| Xdebug                 | —                                          | trigger mode, `host.docker.internal`, FPM port **9003**, CLI port **9004** |
| Composer               | — (deploy with `vendor/`)                  | Composer 2                             |

Published for `linux/amd64` and `linux/arm64`.

## What's in the images

- **Extensions:** bcmath, bz2, calendar, curl, gd, gettext, gmp, iconv, intl,
  mbstring, mysqli, opcache, pcntl (CLI only), pdo_mysql, pdo_pgsql, pdo_sqlite,
  sodium, sqlite3, zip, and the PHP core set. `./test.sh` checks the full list.
  Deliberately **not** included (attack surface most web apps don't need):
  exif, ffi, ftp, shmop, soap, sockets, sysvmsg/sysvsem/sysvshm, xsl --
  `./test.sh` fails if any of them sneak back in.
- **ini** (`conf/php-prod.ini`): `expose_php` off, errors logged not shown,
  256M memory for CLI (FPM: 128M, see below), 100M/110M upload/post, 60s max_execution_time, America/Chicago,
  strict/httponly/secure/Lax session cookies. Opcache is stock.
- **FPM pool** (`conf/fpm-pool.conf`): dynamic, sized for a 4 GB server (see below),
  1000 max requests, 120s request timeout, `exec`/`shell_exec`/`system`/`proc_open`/…
  disabled. CLI keeps `exec` for cron jobs and scripts.

## Server sizing (FPM)

Pool size matters: it caps how many requests PHP runs at once, and so how
much RAM PHP can use. The defaults target a **4 GB RAM, 2–4 vCPU server**
that also runs nginx and the OS, and are sized for the **worst case**, every
worker at its memory limit at once:

    24 workers × 128M memory_limit = 3 GB for PHP, ~1 GB for nginx + OS

So the pool can't push the server into swap or the OOM killer. Typical use
is far lower (an idle worker is ~11 MB, a busy framework app 40–80 MB).

The rule: **`PHP_FPM_MAX_CHILDREN × PHP_FPM_MEMORY_LIMIT` ≤ RAM for PHP**
(server RAM minus ~1 GB). Size it with env vars at `docker run` / compose
time, with no rebuild:

| Server RAM | `PHP_FPM_MAX_CHILDREN` | `_START_SERVERS` | `_MIN_SPARE_SERVERS` | `_MAX_SPARE_SERVERS` |
|-----------:|-----------------------:|-----------------:|---------------------:|---------------------:|
| 1 GB       | 4                      | 2                | 1                    | 3                    |
| 2 GB       | 8                      | 2                | 2                    | 4                    |
| **4 GB**   | **24** (default)       | **5**            | **3**                | **8**                |
| 8 GB       | 56                     | 10               | 6                    | 16                   |

(At the default `PHP_FPM_MEMORY_LIMIT=128M`.) If your app needs more memory
per request, raise `PHP_FPM_MEMORY_LIMIT` and lower `PHP_FPM_MAX_CHILDREN` to
match, e.g. 256M → 12 workers on 4 GB. If the database runs on the same
server, halve the worker counts. Also available:
`PHP_FPM_MAX_REQUESTS` (default 1000) and `PHP_FPM_REQUEST_TERMINATE_TIMEOUT` (120s).

```sh
docker run -e PHP_FPM_MAX_CHILDREN=20 -e PHP_FPM_MAX_SPARE_SERVERS=6 treehousetim/php-fpm-pdo:8.5
```

**Left to the deployment:** pool user, unix sockets (the image listens on `:9000`),
`open_basedir`, log paths and `env[...]`.

**musl vs glibc:** these are Alpine (musl) images, so a few things differ from a
glibc host, e.g. `iconv('UTF-8', 'ASCII//TRANSLIT', 'Café')` gives `Caf'e` here and
`Cafe` on Debian/Ubuntu.

## Usage

```sh
./build.sh                # build all 4 for this machine + run the tests
./build.sh prod           # a group (prod, dev) or one target (cli-prod, fpm-prod, cli-dev, fpm-dev)
./test.sh                 # re-run tests on what's already built
./publish.sh              # multi-arch build + push to Docker Hub (docker login first)
```

These wrap `docker buildx bake`, which builds every target defined in
`docker-bake.hcl` (version, tags, platforms) in one go.

## Bumping PHP

Change `PHP_VERSION` in `docker-bake.hcl` (or one-off: `PHP_VERSION=8.5.14 ./build.sh`),
then `./build.sh && ./publish.sh`. Check the tag exists first:
<https://hub.docker.com/_/php/tags?name=8.5>

To add an extension, add it to the `install-php-extensions` list in the `Dockerfile`
and to `PROD_MODULES` in `test.sh`. Supported names:
<https://github.com/mlocati/docker-php-extension-installer#supported-php-extensions>
