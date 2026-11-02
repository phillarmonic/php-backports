#!/usr/bin/env bash
#
# Select the rows of .github/ci-matrix.tsv that apply to the branch under test
# and write them out as two JSON matrices for the build workflow.
#
# Everything comes in through the environment so the script also runs by hand:
#
#   GITHUB_HEAD_REF / GITHUB_REF_NAME / GITHUB_BASE_REF   branch detection
#   DISPATCH_SERIES   "all", one series such as 8.1, or empty
#   CI_MARKERS        enabled runner markers, space or comma separated
#   CI_LABELS         pull request labels, comma separated
#   CI_SUITES         override the suites column
#   GITHUB_OUTPUT     where the workflow reads key=value pairs
#
# An empty matrix is not a valid strategy, so a bucket with no rows is filled
# with one placeholder row and its count is zero. The job skips on the count.

set -euo pipefail

fail() {
    printf 'ci-plan: %s\n' "$*" >&2
    exit 1
}

root=$(git rev-parse --show-toplevel)
matrix_file="$root/.github/ci-matrix.tsv"
[[ -f "$matrix_file" ]] || fail "missing $matrix_file"

dispatch_all=0
dispatch="${DISPATCH_SERIES:-}"
case "$dispatch" in
    all) dispatch_all=1; dispatch="" ;;
    -)   dispatch="" ;;
esac

ref="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"
base="${GITHUB_BASE_REF:-}"

series=""
branch=""

if [[ -n "$dispatch" ]]; then
    series="$dispatch"
    branch="backports/php-$series"
elif (( dispatch_all )); then
    # Every series in the table; each row checks out its own branch.
    :
else
    for candidate in "$ref" "$base"; do
        case "$candidate" in
            backports/php-*)
                series="${candidate#backports/php-}"
                branch="$ref"
                break
                ;;
        esac
    done
fi

selected=1
if [[ -z "$series" && $dispatch_all -eq 0 ]]; then
    selected=0
    printf 'ci-plan: %s is not a backports/php-* branch; nothing to build\n' "${ref:-<detached>}"
fi

markers=" ${CI_MARKERS:-} "
markers="${markers//,/ }"
if [[ -n "${CI_LABELS:-}" ]]; then
    IFS=',' read -r -a labels <<< "$CI_LABELS"
    for label in "${labels[@]}"; do
        case "$label" in
            ci:?*) markers+=" ${label#ci:} " ;;
        esac
    done
fi

linux_rows=()
windows_rows=()
linux_count=0
windows_count=0

rows_file="$matrix_file"
if (( ! selected )); then
    rows_file=/dev/null
fi

while IFS=$'\t' read -r s t r p c a tool suites marker; do
    if [[ -z "${s:-}" || "$s" == '#'* || "$s" == series ]]; then
        continue
    fi
    if [[ -z "${marker:-}" ]]; then
        fail "row for $s/$t is missing the marker column"
    fi
    if [[ -n "$series" && "$s" != "$series" ]]; then
        continue
    fi
    if [[ "$marker" != - ]]; then
        case " $markers " in
            *" $marker "*) ;;
            *) continue ;;
        esac
    fi
    if [[ -n "${CI_SUITES:-}" ]]; then
        suites="$CI_SUITES"
    fi
    if [[ -z "${t:-}" || -z "${r:-}" ]]; then
        fail "row for $s is missing target or runner"
    fi

    row_branch="$branch"
    if [[ -z "$row_branch" ]]; then
        row_branch="backports/php-$s"
    fi

    row=$(printf '{"series":"%s","target":"%s","runner":%s,"platform":"%s","crt":"%s","arch":"%s","toolset":"%s","suites":"%s","marker":"%s","branch":"%s"}' \
        "$s" "$t" "$r" "$p" "$c" "$a" "$tool" "$suites" "$marker" "$row_branch")

    case "$t" in
        linux*)   linux_rows+=("$row");   linux_count=$((linux_count + 1)) ;;
        windows*) windows_rows+=("$row"); windows_count=$((windows_count + 1)) ;;
        *) fail "unknown target '$t' for series $s" ;;
    esac
done < "$rows_file"

if [[ -n "$series" ]] && (( linux_count + windows_count == 0 )); then
    fail "no rows for series $series in .github/ci-matrix.tsv"
fi

placeholder() {
    printf '{"series":"none","target":"%s","runner":["ubuntu-24.04"],"platform":"linux/amd64","crt":"-","arch":"-","toolset":"-","suites":"-","marker":"-","branch":"%s"}' \
        "$1" "${ref:-default}"
}

if (( ${#linux_rows[@]} == 0 )); then
    linux_rows=("$(placeholder linux-none)")
fi
if (( ${#windows_rows[@]} == 0 )); then
    windows_rows=("$(placeholder windows-none)")
fi

json_array() {
    local first=1 item
    printf '['
    for item in "$@"; do
        if (( first )); then
            first=0
        else
            printf ','
        fi
        printf '%s' "$item"
    done
    printf ']'
}

linux_json=$(json_array "${linux_rows[@]}")
windows_json=$(json_array "${windows_rows[@]}")

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        printf 'linux-matrix=%s\n' "$linux_json"
        printf 'linux-count=%s\n' "$linux_count"
        printf 'windows-matrix=%s\n' "$windows_json"
        printf 'windows-count=%s\n' "$windows_count"
        printf 'series=%s\n' "${series:-all}"
    } >> "$GITHUB_OUTPUT"
fi

printf 'series        %s\n' "${series:-all}"
printf 'linux rows    %d\n' "$linux_count"
printf 'windows rows  %d\n' "$windows_count"
printf 'markers       %s\n' "${markers// /}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        printf '### CI plan\n\n'
        printf 'Series: **%s**. Linux rows: %d. Windows rows: %d.\n\n' "${series:-all}" "$linux_count" "$windows_count"
        if command -v jq >/dev/null 2>&1; then
            printf '| series | target | runner | suites |\n| --- | --- | --- | --- |\n'
            for matrix in "$linux_json" "$windows_json"; do
                printf '%s\n' "$matrix" | jq -r '.[] | select(.series != "none") | "| \(.series) | \(.target) | \(.runner | join("/")) | \(.suites) |"'
            done
        fi
    } >> "$GITHUB_STEP_SUMMARY"
fi
