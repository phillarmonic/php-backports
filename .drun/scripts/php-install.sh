#!/usr/bin/env bash
#
# Runs inside the build container. Installs the compiled tree into a staging
# directory and writes one ini line per shared module, so the runtime image
# loads exactly the set this build produced instead of a list kept elsewhere.
#
# The tree is configured with --prefix=/usr/local, so every path compiled into
# the binary names its final location. INSTALL_ROOT moves the files to the
# staging directory without changing those paths, which is what keeps
# extension_dir valid once the prefix lands at /usr/local in the image.
#
# Usage: php-install.sh [prefix] [staging]

set -euo pipefail

prefix="${1:-/usr/local}"
staging="${2:-/build/php-root}"
ini_dir="$staging$prefix/etc/php/conf.d"
ini="$ini_dir/00-backports.ini"

cd /build
make install INSTALL_ROOT="$staging"

mkdir -p "$ini_dir"
: > "$ini"

for so in "$staging$prefix"/lib/php/extensions/*/*.so; do
    if [[ ! -e "$so" ]]; then
        continue
    fi
    name=$(basename "$so" .so)
    case "$name" in
        # Zend extensions load before ordinary ones and take their own directive.
        opcache) printf 'zend_extension=%s.so\n' "$name" >> "$ini" ;;
        *)       printf 'extension=%s\n' "$name" >> "$ini" ;;
    esac
done

sort -u -o "$ini" "$ini"

printf 'Staged %s under %s\n' "$prefix" "$staging"
printf 'Modules in %s:\n' "$ini"
cat "$ini"
