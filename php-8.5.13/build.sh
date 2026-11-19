#!/usr/bin/env bash
# Build all images for this machine's architecture, load them into the local
# docker image store, then smoke-test them.
#   ./build.sh                  # everything
#   ./build.sh prod             # a group (prod, dev) or one target (cli-prod, fpm-prod, cli-dev, fpm-dev)
#   PHP_VERSION=8.5.14 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

docker buildx bake --load "$@"
./test.sh "$@"
