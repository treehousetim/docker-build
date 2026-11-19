<!-- Docker Hub short description (max 100 chars):
Deprecated: use treehousetim/php-fpm-pdo:<version>-dev. Legacy PHP 7.0-8.3 FPM images with Xdebug.
-->
# treehousetim/php-fpm-pdo-xdebug (deprecated)

> **Deprecated.** From PHP 8.5 on, Xdebug images live in the main repo as `-dev`
> tags: use **[`treehousetim/php-fpm-pdo:8.5-dev`](https://hub.docker.com/r/treehousetim/php-fpm-pdo)**.
> This repo gets no new tags or security updates.

## Migrating

| Before                                     | Now                                   |
|--------------------------------------------|---------------------------------------|
| `treehousetim/php-fpm-pdo-xdebug:8.3`      | `treehousetim/php-fpm-pdo:8.5-dev`    |
| `treehousetim/php-fpm-pdo:8.3`             | `treehousetim/php-fpm-pdo:8.5` (or `8.5-prod`) |

The `-dev` image adds Xdebug (trigger mode, port 9003, `host.docker.internal`),
Composer 2, and the development php.ini on top of the production image, so dev
and production run the same PHP build and extensions. Unlike the newer tags
here, it really does include Xdebug.

## Existing tags

`8.3`, `8.2`, `8.1`, `8.0` and `7.0` stay available for existing setups but are
unmaintained. **`8.1`, `8.2` and `8.3` don't contain Xdebug**: they're the same
images as the matching `php-fpm-pdo` tags. `8.1` and older are amd64-only.
