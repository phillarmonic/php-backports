# Agents

This repository is a security-backport fork of php-src, maintained by
Phillarmonic Software. It is not upstream PHP, and it is not the PHP Foundation.
Read [README.md](README.md) and [BACKPORTING.md](BACKPORTING.md) before changing
anything.

## Branches

- `master` mirrors `php/php-src`. Never commit to it, never merge it into a
  backport branch, never publish from it.
- `default` holds documentation, policy, and tooling. This is the repository
  default.
- `backports/php-X.Y` holds patched trees for 5.6, 7.0 through 7.4, 8.0, and
  8.1. Each is release-shaped: security fixes, version bumps, and the build
  identity patch only.

Do not open a pull request against `php/php-src`, and do not file vulnerability
reports on the project's behalf. Before opening a pull request here, search the
existing ones, including closed ones, for the same advisory.

## What may be committed

Allowed: backports of public security advisories with a regression test, the
build identity patch, release notes, and documentation.

Not allowed: features, RFC work, refactors, dependency bumps, deprecations,
performance changes, or ordinary bug fixes. Do not merge upstream history into a
backport branch.

## Security

Never publish a backport, tag, or release before the upstream advisory is public.
Never put unpublished vulnerability details in an issue or pull request.
[SECURITY.md](SECURITY.md) names the only channel for new reports.

## Working

- Every backport cites its upstream commit and carries a test.
- Run the touched extension's tests and `tests/lang` on the branch
  (`xdrun test-ext ext=phar`, `xdrun test-lang`).
- A push, a tag, a release, a force-push, or a write to `master` is a
  stop-and-ask. Local commits are fine.
- Report what you actually ran. A skipped test is not a pass.

## Automation

Repetitive work runs through [drun](https://github.com/phillarmonic/drun): the
spec in `.drun/spec.drun` and the `xdrun` binary. Use the tasks instead of
retyping configure lines and test invocations.

| Task | Does |
| --- | --- |
| `xdrun --list` | List every task and its parameters. |
| `xdrun doctor` | Report the toolchain, the branch, and the tree version. Fails when the branch cannot build. |
| `xdrun build` | Run `buildconf` and `configure` when needed, then compile. |
| `xdrun configure flags="..."` | Configure with a chosen feature set. |
| `xdrun configure-debug` | Configure `--enable-debug` for memory-safety work. |
| `xdrun rebuild` | Distclean, buildconf, and compile from scratch. |
| `xdrun test` | Full suite with `NO_INTERACTION=1`; `filter=` and `jobs=` narrow and parallelize it. |
| `xdrun test-ext ext=phar` | One extension's suite. |
| `xdrun test-lang` | `tests/lang`. |
| `xdrun valgrind target=ext/phar` | A suite target under Valgrind. |
| `xdrun valgrind-repro script=repro.php` | One script with `USE_ZEND_ALLOC=0`. |
| `xdrun lint` | Syntax-check changed `.php` files. |
| `xdrun verify-commits` | Check commit messages against this file. |
| `xdrun verify-identity` | Check that `php -v` carries the Phillarmonic line. |
| `xdrun changelog version=7.4.34` | Promote the Unreleased changelog section on `default` for a release. |
| `xdrun ci-quick` | Commit messages, syntax, `tests/lang`. |
| `xdrun ci` | Commit messages, build, syntax, full suite. |

Rules:

- `xdrun doctor` comes first on a host build. System bison is often older than
  3.0, re2c is often absent, and the build fails late and confusingly without
  them. Homebrew keeps a current bison keg-only; `.drun/scripts/doctor.sh` names
  what to install. For anything other than changing the build system itself,
  use the `docker-*` tasks below, which need only Docker.
- `xdrun build` is a minimal build: `--disable-all --enable-cli`. That is
  deliberate for a backport tree. Add the extensions an advisory touches:
  `xdrun configure flags="--disable-all --enable-cli --enable-phar"`. An
  extension that links a library takes `--with-`, not `--enable-`:
  `--with-openssl`, `--with-pgsql`, `--with-ldap`, `--with-libxml`. Under
  `--disable-all`, SOAP needs `--with-libxml` named explicitly.
- `xdrun lint` and `xdrun verify-identity` use the CLI built from the branch,
  never the host's `php`. A host PHP is the wrong grammar for 5.6 and 7.x and
  gives the wrong answer in both directions.
- `xdrun verify-commits` checks the tip commit by default. A whole branch needs
  a range: `xdrun verify-commits range=origin/backports/php-7.4..HEAD`.
- The test tasks set `REPORT_EXIT_STATUS=1`. Without it `run-tests.php` prints
  its summary and exits 0 even when tests failed, so a green task would mean
  nothing. A task that runs the suite has to keep it.
- `xdrun ci` is the gate before asking to push. Report the failures it found,
  not the wrapper that produced them.
- The spec must not gain a task that pushes, tags, publishes, or force-pushes.
  Those stay stop-and-ask, on the command line, with a human deciding.

### Container builds

`.drun/docker/Dockerfile` and `.drun/scripts/docker.sh` build and test the
checked-out branch with nothing on the host but Docker. The base is
`php:8.1-cli-bullseye`: PHP 8.1 for `build/gen_stub.php`, and OpenSSL 1.1.1 for
7.4 and 8.0. Bullseye is past end of life, so the image pins apt at
`archive.debian.org`, where the pool is still complete.

The build is out of tree in `.build/` (gitignored), and the container runs as
the host UID, so files it writes belong to you.

| Task | Does |
| --- | --- |
| `xdrun docker-doctor` | Report the toolchain inside the image. Start here. |
| `xdrun docker-image` | Build the image; `docker-*` tasks do this on first use. |
| `xdrun docker-buildconf` | Regenerate `configure` in the mounted source. |
| `xdrun docker-configure flags="..."` | Configure the out-of-tree build. |
| `xdrun docker-build jobs=8` | Configure when needed, then compile. |
| `xdrun docker-test filter=... jobs=8` | Full suite, optionally narrowed. |
| `xdrun docker-test-ext ext=session jobs=8` | One extension's suite. |
| `xdrun docker-test-lang jobs=8` | `tests/lang`. |
| `xdrun docker-lint` | Changed `.php` checked by the container CLI. |
| `xdrun docker-verify-commits range=...` | Commit-message check. |
| `xdrun docker-verify-identity` | The Phillarmonic line is in `php -v`. |
| `xdrun docker-valgrind target=ext/phar` | A suite target under Valgrind. |
| `xdrun docker-clean`, `docker-distclean`, `docker-rebuild` | Build-state housekeeping. |
| `xdrun docker-shell` | A shell at `/src` in the image. |
| `xdrun docker-ci-quick`, `xdrun docker-ci` | The same gates as `ci-quick` and `ci`. |

Two branch-dependent behaviours are automatic; do not work around them:

- PHP 5.6 through 7.3 define `YYERROR_VERBOSE` in the parser prologue and need
the bison that still emits `yystrlen` and `yystpcpy` for it. Bison 3.6 removed
that, so those branches use the 3.3.2 build at `/opt/bison33`; 7.4 and later use
the default 3.7. The runner picks by the version in `main/php_version.h`.
- `run-tests.php` gained `-j` in 7.2. On 5.6, 7.0, and 7.1 the runner says so
and runs serially rather than passing a flag that would only print usage.

PHP 5.6 is the one branch that needs a source change to build on ARM. Its
AArch64 inline assembly in `Zend/zend_multiply.h` uses the `"X"` constraint,
which permits memory operands, so GCC emits `mul` against memory and the
assembler rejects it. 7.4 and later already use `"=&r"` for the outputs and
`"r"` for the inputs. The 5.6 branch carries that same two-line change in its
`Fork:` setup commit, never in a `Backport:` commit. The block is compiled only
on AArch64, so the patch is inert on x86_64 and the branch builds both ways.

On macOS the source is bind-mounted, so a test that asserts Unix permission bits
on a file in the tree can fail. `ext/session/tests/bug42596.phpt` is the known
one: it expects mode `100777` and the mount reports `100755`. That is the mount,
not the patch. The same applies to the permission variations under
`ext/standard/tests/file` and `ext/standard/tests/dir`: through the mount a file
comes out `0644` where the test set `0666`. About thirty of those fail on a
macOS host, in the container as much as outside it, because the mount is the
host's.

`PHP_BACKPORTS_IMAGE`, `PHP_BACKPORTS_BASE_IMAGE`, `PHP_BACKPORTS_BUILD_DIR`,
`PHP_BACKPORTS_PLATFORM`, and `PHP_BACKPORTS_DOCKER_USER` override the runner's
defaults.

`.drun/` and `.github/` are fork tooling, so each `backports/php-*` branch
carries them in its setup commit together with this file and `.gitmessage`.

### Continuous integration

`.github/workflows/build.yml` builds and tests a branch on push and on pull
request. It reads `.github/ci-matrix.tsv`, which is the support matrix: one row
per series and platform, naming the runner labels, the container platform or
the Visual C++ generation and toolset, and the suites to run. Add a platform by
adding a row.

Hosted runners cover Linux for every series, and Windows for 7.4, 8.0, and 8.1
only. Windows 7.0 through 7.3 need a self-hosted machine with VS2015 or VS2017,
so those rows carry the `win-legacy` marker. A marked row stays out of the
matrix unless the marker is enabled with the workflow input or a
`ci:win-legacy` label; that is what keeps a powered-off machine from queueing a
job for hours. Windows 5.6 has no row at all, because `phpsdk_setshell.bat`
rejects anything below `vc14` and the vc11 dependencies survive only in
php.net's archive.

The Windows job does not pick its own compiler. It calls
`phpsdk-<crt>-<arch>.bat -s <toolset> -t .github/scripts/windows-build.cmd`, and
that script fails when `PHP_SDK_VS` does not match the row it was given. A
mislabelled machine therefore stops before it can build a release against the
wrong runtime.

`image.yml` publishes the toolchain image for both architectures, tagged with
the hash of `.drun/docker/`. `parity.yml` compares the managed tooling set
across `backports/` branches. GitHub loads a workflow from the commit being
built, so there is no shared copy to maintain; the parity check is what keeps
the per-branch copies from drifting.

`release-image.yml` runs on a `php-*` tag and publishes
`phillarmonic/php-backports:<version>` and `<series>` to Docker Hub for amd64
and arm64. It builds the tagged commit through
`.drun/scripts/build-php-image.sh`, never a working tree, and needs the
`DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` repository secrets. Releases
otherwise carry source only: no tarball, no binary download. The toolchain image
stays on GHCR because every Linux job pulls it, and Docker Hub rate-limits
anonymous pulls from the addresses GitHub runners share.

## Commit messages

Use one of these prefixes, and nothing else:

| Prefix | Use for |
| --- | --- |
| `Backport:` | A security fix ported from upstream. Always carries trailers. |
| `Fork:` | A change that exists only because this is a fork: identity banner, version numbering, branch setup, policy. |
| `Docs:` | Documentation only. |
| `Release:` | The version bump and changelog for a tag. |
| `Revert:` | Reverting a backport. Say why in the body. |

A backport commit looks like this:

```text
Backport: fix integer overflow in phar metadata parsing

The length field was multiplied without a bounds check, so a crafted phar
could wrap the allocation and write past the buffer. The upstream fix adds
the check and rejects the entry.

Adapted for 7.4: upstream moved the check into a helper that does not exist
on this branch, so it is inlined.

Test: ext/phar/tests/bug12345.phpt (new)

CVE: CVE-2024-12345
Upstream: 0123456789abcdef0123456789abcdef01234567
Advisory: https://github.com/php/php-src/security/advisories/GHSA-xxxx
```

- `Upstream:` is the full 40-character SHA. `CVE:` repeats for each CVE.
  `Advisory:` is optional.
- `Fork:` and `Docs:` commits need no trailers.
- The build identity commit uses `Fork: identify Phillarmonic builds` and
  touches only the version output and its test.

Rules:

- one commit per advisory per branch; squash adaptation and test fixups, so
  `git log backports/php-X.Y` reads as the list of fixes in that series;
- subject under 72 characters, imperative, no trailing period; body wrapped at
  72, explaining why and what was adapted, not narrating the diff;
- keep `backports/` linear: rebase and fast-forward, no merge commits;
- sign tags, and prefer signed commits;
- if a commit is pushed anywhere public before the advisory is public, no
  vulnerability name, no CVE trailer, no exploit detail;
- do not amend or force-push pushed commits.

Do not use Conventional Commits. No tooling consumes the types, and nearly every
commit here is a fix, so the type carries no information. Do not use upstream's
`Fix GH-NNNNN:` form either, because a backport here is not fixing a tracker
issue and often has an advisory instead of one.

`.gitmessage` holds the template. Enable it per clone with
`git config commit.template "$(git rev-parse --show-toplevel)/.gitmessage"`.
