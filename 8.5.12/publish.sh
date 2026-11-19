#!/usr/bin/env bash
# Build multi-arch (amd64 + arm64) and push to Docker Hub.
# Run ./build.sh first -- it smoke-tests the images; this does not.
#   ./publish.sh                # everything
#   ./publish.sh prod           # a group (prod, dev) or one target
set -euo pipefail
cd "$(dirname "$0")"

PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}" \
  docker buildx bake --push "$@"
