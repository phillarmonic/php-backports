#!/usr/bin/env bash
# Check commit messages against the convention in AGENTS.md.
#
# Usage: verify-commits.sh [RANGE]
#   RANGE is anything git rev-list accepts. The default, HEAD, checks the tip
#   commit only. Pass base..HEAD to check a whole backport branch.

set -euo pipefail

range="${1:-HEAD}"
prefixes='Backport|Fork|Docs|Release|Revert'
subject_re="^($prefixes): .+"

if [[ "$range" == *..* ]]; then
    commits=$(git rev-list "$range")
    merges=$(git rev-list --merges "$range")
else
    commits=$(git rev-list -n 1 "$range")
    merges=""
fi

if [[ -z "$commits" ]]; then
    echo "No commits in range $range."
    exit 0
fi

status=0
problem() {
    printf '%s: %s\n' "$1" "$2" >&2
    status=1
}

for sha in $commits; do
    subject=$(git log -1 --format=%s "$sha")
    body=$(git log -1 --format=%b "$sha")

    if ! [[ "$subject" =~ $subject_re ]]; then
        problem "$sha" "subject must start with Backport:, Fork:, Docs:, Release: or Revert: (got: $subject)"
        continue
    fi
    prefix="${BASH_REMATCH[1]}"

    if (( ${#subject} > 71 )); then
        problem "$sha" "subject is ${#subject} characters; keep it under 72 (got: $subject)"
    fi
    if [[ "$subject" == *. ]]; then
        problem "$sha" "subject ends with a period (got: $subject)"
    fi

    if [[ "$prefix" == "Backport" ]]; then
        if ! grep -Eq '^Upstream: [0-9a-f]{40}$' <<<"$body"; then
            problem "$sha" "Backport commit needs a full 'Upstream: <40-character SHA>' trailer"
        fi
        if ! grep -Eq '^CVE: CVE-[0-9]{4}-[0-9]+' <<<"$body" &&
            ! grep -Eq '^Advisory: https?://' <<<"$body"; then
            problem "$sha" "Backport commit needs a 'CVE:' or 'Advisory:' trailer"
        fi
        if ! grep -Eq '^Test: .+' <<<"$body"; then
            problem "$sha" "Backport commit needs a 'Test:' line naming the test that was run"
        fi
    fi
done

if [[ -n "$merges" ]]; then
    for sha in $merges; do
        problem "$sha" "merge commit; keep backports/ linear (rebase and fast-forward)"
    done
fi

if [[ $status -eq 0 ]]; then
    echo "Commit messages OK: $(printf '%s\n' "$commits" | wc -l | tr -d ' ') commit(s) checked."
fi
exit $status
