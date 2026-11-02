#!/usr/bin/env bash
# Report the toolchain this tree will build with.
#
# Exits non-zero when a required tool is missing or too old to configure the
# branch, so it can gate a build. Valgrind is optional: only the memory-safety
# tasks need it.

set -u

missing=0

report() {
    local name="$1" binary="$2" requirement="${3:-required}"
    if ! command -v "$binary" >/dev/null 2>&1; then
        if [[ "$requirement" == "optional" ]]; then
            printf '%-12s missing (optional)\n' "$name"
        else
            printf '%-12s missing\n' "$name"
            missing=1
        fi
        return
    fi
    printf '%-12s %s\n' "$name" "$("$binary" --version 2>&1 | head -n 1)"
}

if command -v git >/dev/null 2>&1; then
    printf '%-12s %s\n' "branch" "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

if [[ -f main/php_version.h ]]; then
    version=$(sed -n 's/^#define PHP_VERSION "\(.*\)"/\1/p' main/php_version.h)
    printf '%-12s %s\n' "tree" "${version:-unknown}"
fi

report "cc" cc
report "make" make
report "autoconf" autoconf

if command -v bison >/dev/null 2>&1; then
    bison_line=$(bison --version 2>&1 | head -n 1)
    bison_major=$(printf '%s\n' "$bison_line" | sed -n 's/.* \([0-9][0-9]*\)\..*/\1/p')
    printf '%-12s %s\n' "bison" "$bison_line"
    if [[ -n "$bison_major" ]] && (( bison_major < 3 )); then
        printf '%-12s %s\n' "" "needs 3.0 or newer; Homebrew keeps it keg-only: brew install bison"
        missing=1
    fi
else
    printf '%-12s missing\n' "bison"
    missing=1
fi

report "re2c" re2c
report "pkg-config" pkg-config
report "git" git
report "valgrind" valgrind optional

if [[ $missing -ne 0 ]]; then
    printf '\nInstall the missing tools, then rerun xdrun doctor.\n' >&2
    exit 1
fi

printf '\nToolchain looks usable.\n'
