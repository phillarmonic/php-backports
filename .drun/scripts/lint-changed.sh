#!/usr/bin/env bash
# Syntax-check PHP files touched in the working tree with the CLI built from
# this branch.
#
# The host's PHP is deliberately not used: it rejects syntax older branches
# still support, and accepts syntax they do not.

set -euo pipefail

php_bin="sapi/cli/php"
if [[ ! -x "$php_bin" ]]; then
    echo "No built CLI at $php_bin. Run 'xdrun build' first." >&2
    exit 1
fi

files=()
if [[ $# -gt 0 ]]; then
    files=("$@")
else
    while IFS= read -r file; do
        files+=("$file")
    done < <(
        {
            git diff --name-only --diff-filter=ACMR HEAD -- '*.php'
            git ls-files --others --exclude-standard -- '*.php'
        } | sort -u
    )
fi

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No changed PHP files; nothing to lint."
    exit 0
fi

status=0
for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    if ! "$php_bin" -l "$file" >/dev/null 2>&1; then
        echo "Syntax error in $file:" >&2
        "$php_bin" -l "$file" >&2 || true
        status=1
    fi
done

if [[ $status -eq 0 ]]; then
    echo "PHP syntax OK (${#files[@]} file(s))."
fi
exit $status
