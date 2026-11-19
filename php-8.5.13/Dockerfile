# syntax=docker/dockerfile:1
#
# treehousetim PHP images: cli + fpm, each in a prod and a dev flavor.
# prod: hardened production defaults (extensions, ini, FPM pool sizing).
# Built via docker-bake.hcl -- see README.md. PHP_VERSION and VARIANT must
# agree with the --target you build (bake handles that for you).

ARG PHP_VERSION=8.5.13
ARG VARIANT=cli
ARG ALPINE_VERSION=3.24

FROM composer:2 AS composer

# ---------------------------------------------------------------------------
# base: PHP + extensions, production php.ini + production overrides
# ---------------------------------------------------------------------------
FROM php:${PHP_VERSION}-${VARIANT}-alpine${ALPINE_VERSION} AS base

# install-php-extensions pulls build deps, compiles, then removes the build
# deps and keeps only the runtime libs -- keeps the image small.
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/

# Extensions on top of what the php base image builds in.
RUN install-php-extensions \
        bcmath \
        bz2 \
        calendar \
        gd \
        gettext \
        gmp \
        intl \
        mysqli \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        zip

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY conf/php-prod.ini $PHP_INI_DIR/conf.d/90-prod.ini

# ---------------------------------------------------------------------------
# prod targets: production php.ini, no xdebug, no composer (deploy with vendor/)
# ---------------------------------------------------------------------------
FROM base AS cli-prod

FROM base AS fpm-prod
# pcntl is CLI-only; keep it out of FPM
RUN rm "$PHP_INI_DIR/conf.d/docker-php-ext-pcntl.ini"
# Pool sizing for a 4 GB RAM server; override with -e at run time.
ENV PHP_FPM_MAX_CHILDREN=40 \
    PHP_FPM_START_SERVERS=6 \
    PHP_FPM_MIN_SPARE_SERVERS=4 \
    PHP_FPM_MAX_SPARE_SERVERS=10 \
    PHP_FPM_MAX_REQUESTS=1000 \
    PHP_FPM_REQUEST_TERMINATE_TIMEOUT=120s
COPY conf/fpm-pool.conf /usr/local/etc/php-fpm.d/z-override.conf
RUN mkdir -p /opt/site && chown www-data:www-data /opt/site
WORKDIR /opt/site

# ---------------------------------------------------------------------------
# dev targets: prod + xdebug + composer + development php.ini.
# Never run in production.
# ---------------------------------------------------------------------------
FROM cli-prod AS cli-dev
RUN install-php-extensions xdebug \
 && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY conf/php-dev.ini $PHP_INI_DIR/conf.d/95-dev.ini
COPY conf/xdebug-cli.ini $PHP_INI_DIR/conf.d/z-xdebug.ini

FROM fpm-prod AS fpm-dev
RUN install-php-extensions xdebug \
 && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY conf/php-dev.ini $PHP_INI_DIR/conf.d/95-dev.ini
COPY conf/xdebug-fpm.ini $PHP_INI_DIR/conf.d/z-xdebug.ini
