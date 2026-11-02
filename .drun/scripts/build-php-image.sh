#!/usr/bin/env bash
#
# Build a runtime image from the checked-out tree, for the current architecture.
#
# The build goes through .drun/scripts/docker.sh, so the image contains the same
# tree the test suite ran against: same configure line, same toolchain image,
# same out-of-tree build. Nothing is rebuilt a second way.
#
# Usage: build-php-image.sh <tag> [image]
#
#   tag    tag for the local image, for example 8.1.34-amd64
#   image  repository name, default phillarmonic/php-backports
#
# Environment:
#   PHP_BACKPORTS_IMAGE       toolchain image to build inside
#   PHP_BACKPORTS_IMAGE_BASE  runtime base, default debian:bullseye-slim

set -euo pipefail

die() {
    printf 'php-image: %s\n' "$*" >&2
    exit 1
}

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git checkout"
tag="${1:-}"
[[ -n "$tag" ]] || die "usage: build-php-image.sh <tag> [image]"
image="${2:-phillarmonic/php-backports}"
runtime_base="${PHP_BACKPORTS_IMAGE_BASE:-debian:bullseye-slim}"

version=$(sed -n 's/^#define PHP_VERSION "\(.*\)"/\1/p' "$root/main/php_version.h" 2>/dev/null || true)
[[ -n "$version" ]] || die "main/php_version.h has no PHP_VERSION"
series="${version%.*}"
revision=$(git -C "$root" rev-parse HEAD)

# A build directory of its own, so an image build never disturbs the one a
# developer or the test workflow has configured.
build_dir="$root/.build/image"
prefix=/usr/local
staging=/build/php-root
export PHP_BACKPORTS_BUILD_DIR="$build_dir"

# The runtime set.
#
# The prefix is the path the binary uses at run time, so configure it as the
# final location and let the install step stage it with INSTALL_ROOT. CGI and
# phpdbg are switched off because the image serves the CLI only.
#
# The two config-file flags are explicit: PHP looks for the ini under the prefix
# it was configured with, which is the same directory, but the scan directory is
# not guaranteed to be the conf.d the install step writes into.
flags=(
    --prefix="$prefix"
    --disable-all
    --enable-cli
    --disable-cgi
    --disable-phpdbg
    --enable-phar
    --enable-session
    --enable-filter
    --enable-sockets
    --enable-pcntl
    --enable-bcmath
    --enable-exif
    --enable-soap
    --enable-mbstring
    --enable-opcache
    --enable-ctype
    --enable-tokenizer
    --enable-fileinfo
    --enable-posix
    --enable-calendar
    --enable-ftp
    --enable-dom
    --enable-simplexml
    --enable-xml
    --enable-xmlreader
    --enable-xmlwriter
    --with-iconv
    --with-zlib
    --with-curl
    --enable-pdo
    --with-pdo-sqlite
    --with-sqlite3
    --with-pdo-mysql=mysqlnd
    --with-mysqli=mysqlnd
    --with-pgsql
    --with-pdo-pgsql
    --with-ldap
    --with-config-file-path="$prefix/etc/php"
    --with-config-file-scan-dir="$prefix/etc/php/conf.d"
)

# 5.6 spells libxml as --enable; from 7.0 it is a library, so --with.
case "$series" in
    5.*) flags+=(--enable-libxml) ;;
    *)   flags+=(--with-libxml) ;;
esac

# hash and json became unconditionally available in 8.0, so only the older
# branches take the flags. Everything else in the list above exists from 5.6 to
# 8.1 with the same spelling.
case "$series" in
    5.*|7.*) flags+=(--enable-hash --enable-json) ;;
esac

# PHP 5.6 and 7.0 predate OpenSSL 1.1 and do not compile against it. The
# toolchain carries 1.1.1, so those two ship without ext/openssl rather than
# against a library older than the one php.net archived.
case "$series" in
    5.*|7.0) ;;
    *)       flags+=(--with-openssl) ;;
esac

# 5.6 looks for libraries in /usr/lib only. Debian puts them in a multiarch
# directory, so name it explicitly on the branches that predate pkg-config use.
case "$series" in
    5.*|7.0|7.1|7.2|7.3)
        case "$(uname -m)" in
            aarch64|arm64) flags+=(--with-libdir=lib/aarch64-linux-gnu) ;;
            x86_64|amd64)  flags+=(--with-libdir=lib/x86_64-linux-gnu) ;;
        esac
        ;;
esac

jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)

rm -rf "$build_dir"
"$root/.drun/scripts/docker.sh" configure "${flags[@]}"
"$root/.drun/scripts/docker.sh" build "$jobs"
"$root/.drun/scripts/docker.sh" install "$staging"

[[ -x "$build_dir/php-root$prefix/bin/php" ]] || die "staged prefix has no bin/php"

docker build \
    -f "$root/.drun/php-image/Dockerfile" \
    --build-arg "BASE_IMAGE=$runtime_base" \
    --build-arg "PHP_SERIES=$series" \
    --build-arg "PHP_VERSION=$version" \
    --build-arg "SOURCE_REVISION=$revision" \
    -t "$image:$tag" \
    "$build_dir/php-root"

printf 'Built %s:%s from %s\n' "$image" "$tag" "$version"
