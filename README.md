# docker-build

Build and publish scripts for the `treehousetim/*` Docker Hub images.

## Current: PHP 8.5

`php-8.5.13/` builds `treehousetim/php-cli-pdo` and `treehousetim/php-fpm-pdo`, with
hardened production defaults. Every image comes in two flavors:

| Tag                         | Flavor | Use for                                    |
|-----------------------------|--------|--------------------------------------------|
| `:8.5.13-prod`, `:8.5-prod` | prod   | production, staging, CI                    |
| `:8.5.13`, `:8.5`, `:latest` | prod  | alias of `-prod`                           |
| `:8.5.13-dev`, `:8.5-dev`   | dev    | local development (xdebug, composer, errors shown) |

**A tag without `-dev` is always the prod image.**

```sh
./build.sh        # build + test all images for this machine
./publish.sh      # multi-arch build + push to Docker Hub (docker login first)
```

Both pass arguments through, e.g. `./build.sh prod` or `./build.sh fpm-dev`.
See [`php-8.5.13/README.md`](php-8.5.13/README.md) for what's in the images, how they
match prod, and how to bump the PHP version.

## Layout

```
build.sh, publish.sh   wrappers for the current version (php-8.5.13/)
php-8.5.13/            current PHP images (Dockerfile, docker-bake.hcl, conf/, tests)
hub/                   Docker Hub descriptions (short + full overview) for each repo
```

## Requirements

Docker Desktop (or Docker Engine with buildx). Publishing needs `docker login` as a
user with push access to the `treehousetim` Docker Hub namespace.
