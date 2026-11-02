#!/usr/bin/env bash
# Run php-backports build and test tasks inside the container image.
#
# The host only needs Docker. The image carries bison, re2c, autoconf, the
# compilers, and the development libraries, so a macOS or Linux host with a
# mismatched toolchain builds the same tree.
#
# The source is mounted read-write because ./buildconf writes ./configure.
# The build itself is out of tree in .build/, so the host tree stays free of
# object files.

set -euo pipefail

die() {
    printf 'docker: %s\n' "$*" >&2
    exit 1
}

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git checkout"

image=${PHP_BACKPORTS_IMAGE:-php-backports-build:bullseye}
base_image=${PHP_BACKPORTS_BASE_IMAGE:-php:8.1-cli-bullseye}
build_dir=${PHP_BACKPORTS_BUILD_DIR:-$root/.build}
platform=${PHP_BACKPORTS_PLATFORM:-}

if [[ -n "${PHP_BACKPORTS_DOCKER_USER+x}" ]]; then
    docker_user="$PHP_BACKPORTS_DOCKER_USER"
elif command -v id >/dev/null 2>&1; then
    docker_user="$(id -u):$(id -g)"
else
    docker_user=""
fi

# A linked git worktree keeps its git directory outside the checkout and names
# it with an absolute host path in a .git file. Mount that directory, and the
# repository it borrows from, at the same absolute path inside the container,
# or every git command in there fails with "not a git repository".
extra_mounts=()
if [[ -f "$root/.git" ]]; then
    gitdir=$(sed -n 's/^gitdir: //p' "$root/.git")
    if [[ -n "$gitdir" ]]; then
        [[ "$gitdir" = /* ]] || gitdir="$root/$gitdir"
        extra_mounts+=(-v "$gitdir:$gitdir")
        if [[ -f "$gitdir/commondir" ]]; then
            common=$(<"$gitdir/commondir")
            [[ "$common" = /* ]] || common="$gitdir/$common"
            extra_mounts+=(-v "$common:$common")
        fi
    fi
fi

tree_version=""
if [[ -f "$root/main/php_version.h" ]]; then
    tree_version=$(sed -n 's/^#define PHP_VERSION "\(.*\)"/\1/p' "$root/main/php_version.h")
fi

# Bison 3.7 dropped the yystrlen and yystpcpy helpers that 5.6 through 7.3
# expect from the YYERROR_VERBOSE prologue macro, so their parser fails to link.
# Those branches use the 3.3.2 build the image carries at /opt/bison33. The
# value is the container's own PATH, since expanding $PATH here would splice in
# the host's.
container_path=""
case "$tree_version" in
    5.*|7.0.*|7.1.*|7.2.*|7.3.*)
        container_path="/opt/bison33/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ;;
esac

# run-tests.php only grew -j in 7.2. On older branches it rejects the flag and
# prints its usage text instead of running anything.
supports_parallel_tests=1
case "$tree_version" in
    5.*|7.0.*|7.1.*) supports_parallel_tests=0 ;;
esac

# GCC 10 defaults to -fno-common, which breaks PHP 7.x and 5.6. Newer series do
# not need it, and keeping it off avoids changing their semantics.
cflags="${CFLAGS:-}"
case "$tree_version" in
    5.*|7.*) cflags="${cflags:+$cflags }-fcommon" ;;
esac

require_docker() {
    command -v docker >/dev/null 2>&1 || die "docker is not on PATH"
}

build_image() {
    require_docker
    local -a args=(build --build-arg "BASE_IMAGE=$base_image" -t "$image" -f "$root/.drun/docker/Dockerfile")
    if [[ -n "$platform" ]]; then
        args+=(--platform "$platform")
    fi
    args+=("$root/.drun/docker")
    docker "${args[@]}"
}

ensure_image() {
    require_docker
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        printf 'Image %s is missing; building it once.\n' "$image"
        build_image
    fi
}

docker_run() {
    local workdir="$1"
    shift
    mkdir -p "$build_dir"
    local -a args=(run --rm)
    if [[ -n "$platform" ]]; then
        args+=(--platform "$platform")
    fi
    if [[ -n "$docker_user" ]]; then
        args+=(--user "$docker_user")
    fi
    # REPORT_EXIT_STATUS is what makes run-tests.php exit non-zero on a failure.
    # Without it the suite reports FAIL and still exits 0, so a green job means
    # nothing.
    args+=(-e HOME=/tmp -e NO_INTERACTION=1 -e REPORT_EXIT_STATUS=1)
    # Every command below runs under a non-login shell: a login shell would
    # source /etc/profile and reset PATH, discarding this override.
    if [[ -n "$container_path" ]]; then
        args+=(-e "PATH=$container_path")
        # The relocated 3.3.2 binary looks for its m4 skeletons in the prefix it
        # was compiled with. Point it at its own copy, or it mixes 3.3.2 with
        # 3.7's skeletons and emits unexpanded b4_ macros.
        args+=(-e "BISON_PKGDATADIR=/opt/bison33/usr/share/bison")
    fi
    if [[ -n "$cflags" ]]; then
        args+=(-e "CFLAGS=$cflags")
    fi
    args+=(-v "$root:/src" -v "$build_dir:/build" -w "$workdir")
    args+=(${extra_mounts[@]+"${extra_mounts[@]}"})
    if [[ -t 0 && -t 1 ]]; then
        args+=(-it)
    fi
    docker "${args[@]}" "$image" "$@"
}

git_safe() {
    printf 'git config --global --add safe.directory /src >/dev/null 2>&1 || true; '
}

run_buildconf() {
    ensure_image
    docker_run /src bash -c './buildconf --force'
}

run_configure() {
    local flags="$*"
    if [[ -z "$flags" ]]; then
        flags="--disable-all --enable-cli"
    fi
    ensure_image
    if [[ ! -f "$root/configure" ]]; then
        run_buildconf
    fi
    mkdir -p "$build_dir"
    docker_run /build bash -c "cd /build && /src/configure $flags"
}

run_build() {
    local jobs="${1:-}"
    if [[ -n "$jobs" && ! "$jobs" =~ ^[0-9]+$ ]]; then
        die "jobs must be a number"
    fi
    ensure_image
    if [[ ! -f "$build_dir/Makefile" ]]; then
        run_configure
    fi
    if [[ -z "$jobs" ]]; then
        jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    fi
    docker_run /build bash -c "cd /build && make -j$jobs"
}

# Install the build into a prefix inside the mounted build directory, then write
# an ini listing the shared modules it produced. The runtime image consumes the
# prefix, and that ini is what makes the modules load there.
run_install() {
    local staging="${1:-/build/php-root}"
    if [[ ! -f "$build_dir/Makefile" ]]; then
        die "no configured build in $build_dir; run docker-build first"
    fi
    ensure_image
    docker_run /build bash -c "cd /build && /src/.drun/scripts/php-install.sh /usr/local '$staging'"
}

# run-tests.php takes its options and its test paths in one argument list, and
# the Makefile only forwards TESTS, so options go first:
#   make test TESTS="-j4 ext/session"
run_test() {
    local filter="${1:-}"
    local jobs="${2:-}"
    if [[ ! -f "$build_dir/Makefile" ]]; then
        die "no configured build in $build_dir; run docker-build first"
    fi
    if [[ -n "$jobs" && ! "$jobs" =~ ^[0-9]+$ ]]; then
        die "jobs must be a number"
    fi
    local tests=""
    if [[ -n "$jobs" && "$supports_parallel_tests" == 1 ]]; then
        tests="-j$jobs"
    elif [[ -n "$jobs" ]]; then
        printf 'run-tests.php on %s has no -j; running serially.\n' "$tree_version" >&2
    fi
    if [[ -n "$filter" ]]; then
        tests="${tests:+$tests }$filter"
    fi
    local cmd="cd /build && NO_INTERACTION=1 make test"
    if [[ -n "$tests" ]]; then
        cmd="$cmd TESTS=$(printf %q "$tests")"
    fi
    docker_run /build bash -c "$cmd"
}

run_test_ext() {
    local ext="${1:-}"
    local jobs="${2:-}"
    [[ -n "$ext" ]] || die "ext is required"
    [[ "$ext" =~ ^[A-Za-z0-9_]+$ ]] || die "invalid extension name: $ext"
    [[ -d "$root/ext/$ext" ]] || die "no such extension: ext/$ext"
    run_test "ext/$ext" "$jobs"
}

run_test_lang() {
    run_test "tests/lang" "${1:-}"
}

run_lint() {
    ensure_image
    if [[ ! -x "$build_dir/sapi/cli/php" ]]; then
        die "no built CLI at $build_dir/sapi/cli/php; run docker-build first"
    fi
    docker_run /src bash -c "$(git_safe)cd /src && PHP_BIN=/build/sapi/cli/php .drun/scripts/lint-changed.sh"
}

run_verify_commits() {
    local range="${1:-HEAD}"
    [[ -n "$range" ]] || range="HEAD"
    ensure_image
    docker_run /src bash -c "$(git_safe)cd /src && .drun/scripts/verify-commits.sh $(printf %q "$range")"
}

run_verify_identity() {
    ensure_image
    if [[ ! -x "$build_dir/sapi/cli/php" ]]; then
        die "no built CLI at $build_dir/sapi/cli/php; run docker-build first"
    fi
    docker_run /build bash -c "cd /build && /build/sapi/cli/php -v > /tmp/php-backports-version.txt && grep -F 'Phillarmonic Software' /tmp/php-backports-version.txt && grep -F 'not an official PHP release' /tmp/php-backports-version.txt"
}

run_valgrind() {
    local target="${1:-}"
    [[ -n "$target" ]] || die "target is required"
    if [[ ! -f "$build_dir/Makefile" ]]; then
        die "no configured build in $build_dir; run docker-build first"
    fi
    ensure_image
    docker_run /build bash -c 'command -v valgrind >/dev/null 2>&1 || { echo "valgrind is not installed in the image" >&2; exit 1; }'
    docker_run /build bash -c "cd /build && NO_INTERACTION=1 make test TESTS=$(printf %q "-m $target")"
}

run_clean() {
    ensure_image
    if [[ -f "$build_dir/Makefile" ]]; then
        docker_run /build bash -c 'cd /build && make clean'
    else
        printf 'Nothing to clean: %s has no Makefile.\n' "$build_dir"
    fi
}

run_distclean() {
    ensure_image
    if [[ -f "$build_dir/Makefile" ]]; then
        docker_run /build bash -c 'cd /build && make distclean'
    else
        printf 'Nothing to distclean: %s has no Makefile.\n' "$build_dir"
    fi
}

run_rebuild() {
    run_distclean
    run_buildconf
    run_configure
    run_build
}

run_doctor() {
    ensure_image
    docker_run /src bash -c '
        printf "image        %s\n" "$( . /etc/os-release && printf "%s" "$PRETTY_NAME" )"
        printf "bison        %s\n" "$(bison --version | head -n1)"
        printf "bison 3.3    %s\n" "$(/opt/bison33/usr/bin/bison --version | head -n1)"
        printf "re2c         %s\n" "$(re2c --version)"
        printf "php          %s\n" "$(php -v | head -n1)"
        printf "cc           %s\n" "$(cc --version | head -n1)"
        printf "make         %s\n" "$(make --version | head -n1)"
        if command -v valgrind >/dev/null 2>&1; then
            printf "valgrind     %s\n" "$(valgrind --version)"
        else
            printf "valgrind     not installed\n"
        fi
        printf "arch         %s\n" "$(uname -m)"
    '
}

run_shell() {
    ensure_image
    docker_run /src bash
}

run_ci_quick() {
    run_verify_commits HEAD
    run_lint
    run_test_lang ""
}

run_ci() {
    run_verify_commits HEAD
    run_build
    run_lint
    run_test "" 4
}

usage() {
    cat <<'EOF'
Usage: .drun/scripts/docker.sh <command> [arguments]

Commands:
  image                     Build the build image
  doctor                    Report the toolchain inside the image
  buildconf                 Regenerate configure in the mounted source
  configure [flags...]      Configure an out-of-tree build in .build/
  build [jobs]              Compile, configuring first if needed
  install [staging]         Install the build and write its extension ini
  test [filter] [jobs]      Run the test suite
  test-ext <ext> [jobs]     Run one extension's tests
  test-lang [jobs]          Run tests/lang
  lint                      Lint changed PHP with the container CLI
  verify-commits [range]    Check commit messages
  verify-identity           Check the container CLI's version banner
  valgrind <target>         Run a test target under Valgrind
  clean                     Remove objects, keep the build configured
  distclean                 Remove the configured build
  rebuild                   Distclean, buildconf, configure, compile
  shell                     Open a shell in the build container
  ci-quick                  Commit checks, lint, and language tests
  ci                        Commit checks, build, lint, and full tests

Environment:
  PHP_BACKPORTS_IMAGE        Image tag (default php-backports-build:bullseye)
  PHP_BACKPORTS_BASE_IMAGE   Base image for a build (default php:8.1-cli-bullseye)
  PHP_BACKPORTS_BUILD_DIR    Out-of-tree build directory (default .build/)
  PHP_BACKPORTS_PLATFORM     Optional docker --platform, for example linux/amd64
  PHP_BACKPORTS_DOCKER_USER  Container user; set empty to disable --user
  CFLAGS                     Extra compiler flags
EOF
}

command="${1:-}"
if [[ $# -gt 0 ]]; then
    shift
fi

case "$command" in
    image) build_image ;;
    doctor) run_doctor ;;
    buildconf) run_buildconf ;;
    configure) run_configure "$@" ;;
    build) run_build "${1:-}" ;;
    install) run_install "${1:-}" ;;
    test) run_test "${1:-}" "${2:-}" ;;
    test-ext) run_test_ext "${1:-}" "${2:-}" ;;
    test-lang) run_test_lang "${1:-}" ;;
    lint) run_lint ;;
    verify-commits) run_verify_commits "${1:-}" ;;
    verify-identity) run_verify_identity ;;
    valgrind) run_valgrind "${1:-}" ;;
    clean) run_clean ;;
    distclean) run_distclean ;;
    rebuild) run_rebuild ;;
    shell) run_shell ;;
    ci-quick) run_ci_quick ;;
    ci) run_ci ;;
    ""|-h|--help|help) usage ;;
    *) usage; exit 2 ;;
esac
