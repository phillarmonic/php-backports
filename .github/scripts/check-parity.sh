#!/usr/bin/env bash
#
# Fail when the tooling that travels with every backport branch has drifted
# from default. GitHub always loads a workflow from the commit being built, so
# there is no one copy to share; this check is the substitute.

set -euo pipefail

managed=(.github .drun AGENTS.md .gitmessage)
base="${BASE_REF:-origin/default}"
status=0
found=0

while IFS= read -r ref; do
    if [[ -z "$ref" ]]; then
        continue
    fi
    found=1
    if git diff --quiet "$ref..$base" -- "${managed[@]}"; then
        printf 'ok    %s\n' "$ref"
        continue
    fi
    printf 'drift %s\n' "$ref"
    git diff --stat "$ref..$base" -- "${managed[@]}"
    status=1
done < <(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/backports')

if (( found == 0 )); then
    printf 'No backports/* branches yet; nothing to compare.\n'
fi

exit "$status"
