#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/php-8.5.13/build.sh" "$@"
