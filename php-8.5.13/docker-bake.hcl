# docker buildx bake            -> build all four images for this machine, load locally
# docker buildx bake prod       -> just the prod images (groups: prod, dev; or one target, e.g. fpm-dev)
# docker buildx bake --push     -> build multi-arch and push to Docker Hub (see publish.sh)
#
# Bumping PHP: change PHP_VERSION below (or: PHP_VERSION=8.5.14 docker buildx bake).

variable "PHP_VERSION" {
  default = "8.5.13"
}

variable "ALPINE_VERSION" {
  default = "3.24"
}

variable "REPO" {
  default = "treehousetim"
}

# Also tag prod images :latest. Set LATEST=false when publishing an older
# branch (e.g. an 8.4 patch release) so :latest stays on the newest PHP.
variable "LATEST" {
  default = true
}

# Empty = native platform only (needed for --load). publish.sh sets this.
variable "PLATFORMS" {
  default = ""
}

function "minor" {
  params = [v]
  result = join(".", slice(split(".", v), 0, 2))
}

# Every image gets an explicit -prod or -dev tag. The bare version tag is an
# alias for -prod, so a plain `:8.5.13` pull is always safe to deploy. So is
# :latest (newest PHP, prod flavor) unless LATEST=false.
#   php-fpm-pdo:8.5.13  php-fpm-pdo:8.5  php-fpm-pdo:8.5.13-prod  php-fpm-pdo:8.5-prod
#   php-fpm-pdo:8.5.13-dev  php-fpm-pdo:8.5-dev
function "tags" {
  params = [image, flavor]
  result = concat(
    [
      "${REPO}/${image}:${PHP_VERSION}-${flavor}",
      "${REPO}/${image}:${minor(PHP_VERSION)}-${flavor}",
    ],
    flavor == "prod" ? [
      "${REPO}/${image}:${PHP_VERSION}",
      "${REPO}/${image}:${minor(PHP_VERSION)}",
    ] : [],
    flavor == "prod" && LATEST ? ["${REPO}/${image}:latest"] : [],
  )
}

group "default" {
  targets = ["prod", "dev"]
}

group "prod" {
  targets = ["cli-prod", "fpm-prod"]
}

group "dev" {
  targets = ["cli-dev", "fpm-dev"]
}

target "_common" {
  context   = "."
  platforms = PLATFORMS == "" ? [] : split(",", PLATFORMS)
  args = {
    PHP_VERSION    = PHP_VERSION
    ALPINE_VERSION = ALPINE_VERSION
  }
  labels = {
    "org.opencontainers.image.version" = PHP_VERSION
    "org.opencontainers.image.vendor"  = "treehousetim"
  }
}

target "cli-prod" {
  inherits = ["_common"]
  target   = "cli-prod"
  args     = { VARIANT = "cli" }
  tags     = tags("php-cli-pdo", "prod")
  labels   = { "com.treehousetim.image.flavor" = "prod" }
}

target "fpm-prod" {
  inherits = ["_common"]
  target   = "fpm-prod"
  args     = { VARIANT = "fpm" }
  tags     = tags("php-fpm-pdo", "prod")
  labels   = { "com.treehousetim.image.flavor" = "prod" }
}

target "cli-dev" {
  inherits = ["_common"]
  target   = "cli-dev"
  args     = { VARIANT = "cli" }
  tags     = tags("php-cli-pdo", "dev")
  labels   = { "com.treehousetim.image.flavor" = "dev" }
}

target "fpm-dev" {
  inherits = ["_common"]
  target   = "fpm-dev"
  args     = { VARIANT = "fpm" }
  tags     = tags("php-fpm-pdo", "dev")
  labels   = { "com.treehousetim.image.flavor" = "dev" }
}
