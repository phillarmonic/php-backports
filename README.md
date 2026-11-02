# PHP security backports

**Porting fixes of PHP for machines that refuse to die.**

This is a fork of [php-src](https://github.com/php/php-src). It takes security
fixes that PHP applies to versions it still supports and ports them to versions
it does not. A box running PHP 5.6 or 7.4 should not stay exposed to a published
remote code execution bug just because nobody can schedule the migration.

> **This is not the PHP project.** The repository is maintained by
> [Phillarmonic Software](https://www.phillarmonic.com/). It is not affiliated
> with, endorsed by, or supported by the PHP Group, the PHP project, or the PHP
> Foundation. "PHP" here identifies the code base. Every build from these
> branches reports itself as a Phillarmonic backport, and none of them are
> official PHP releases.

**Status:** the backport branches are being cut. Nothing has been released yet.
The first tags will appear on the releases page.

## What we backport

We port fixes for serious vulnerabilities into the last release of each
end-of-life series:

- memory corruption reachable from untrusted input: use after free, out of
  bounds read or write, double free, and the buffer or integer overflows that
  lead to them;
- remote code execution, authentication bypass, and sandbox escapes where the
  fix is small;
- parsing bugs in bundled extensions that turn a request into memory
  corruption, in the `unserialize()`, XML, image, and archive handlers.

The backport has to stay small. We want the checks that stop the bug, not the
refactor that came with them. Where a fix depends on an API the older branch
does not have, we write the smallest version of it that works and add a
regression test.

We do not backport features, RFCs, deprecations, performance work, dependency
bumps, or ordinary bug fixes. Matching current PHP is not a goal. Keeping an old
install out of the advisory list is.

## Coverage

| Series | Last upstream release | Backport branch |
| --- | --- | --- |
| PHP 5.6 | 5.6.40 | `backports/php-5.6` |
| PHP 7.0 | 7.0.33 | `backports/php-7.0` |
| PHP 7.1 | 7.1.33 | `backports/php-7.1` |
| PHP 7.2 | 7.2.34 | `backports/php-7.2` |
| PHP 7.3 | 7.3.33 | `backports/php-7.3` |
| PHP 7.4 | 7.4.33 | `backports/php-7.4` |
| PHP 8.0 | 8.0.30 | `backports/php-8.0` |
| PHP 8.1 | 8.1.34 | `backports/php-8.1` |

Patch levels continue where upstream stopped. The first build of the 7.4 branch
is 7.4.34, the next is 7.4.35, and so on. The version stays numeric: no suffix is
appended to `PHP_VERSION`, so `version_compare()`, Composer platform checks, and
extension version constraints keep behaving as they did.

## How a build identifies itself

A backport must be recognizable at a glance, because a support engineer needs to
know within seconds whether a binary is an official PHP build or ours. Every
branch carries a small identity patch, so a plain build shows:

```text
$ php -v
PHP 7.4.34 (cli) (built: Oct 26 2026 14:02:11) (NTS)
Copyright © The PHP Group and Contributors
Built by Phillarmonic Software (https://www.phillarmonic.com/) - security backport, not an official PHP release
Zend Engine v3.4.0, Copyright (c) Zend Technologies
```

The copyright line stays as upstream wrote it, because the code is still theirs.
The line after it is ours. It lives in the build, not in the version number, so
nothing that compares versions sees a difference. It also appears in
`phpinfo()`, and branches that already define `PHP_BUILD_PROVIDER` expose it as
a constant.

## Sponsoring this work

This is unfunded maintenance. Every backport is read, adapted, built, and tested
by hand, and the old branches need more care than current ones because their
toolchains and test suites have moved on.

If a backport keeps a system you depend on alive, sponsor the work:

> **Donations:** GitHub Sponsors is being set up. The link will appear here once
> the profile is live. Until then there is no official donation channel, and
> anyone asking for money on our behalf is not us.

Sponsorship is a donation. It does not buy a private fix, a guaranteed timeline,
or a say in which vulnerabilities are ported first. Contractual work is
separate: see [paid consultancy](#paid-consultancy).

## Branches

| Branch | Purpose |
| --- | --- |
| `default` | Working branch for this fork: documentation, policy, tooling. It is the repository default, so a fresh clone lands here. |
| `master` | Untouched mirror of `php/php-src` master. Kept clean so the fork stays comparable to upstream and can be fetched without rebasing. Never commit to it. |
| `backports/php-5.6` ... `backports/php-8.1` | The patched trees. Each starts at the final upstream release tag and receives security backports only. |
| `PHP-5.6`, `PHP-7.4`, ... | Upstream refs carried by the mirror. We do not commit to them and do not publish from them. |

Each release is a tag on its `backports/` branch, in upstream's `php-x.y.z` form,
with release notes listing the advisories it includes. Released changes are
indexed in [CHANGELOG.md](CHANGELOG.md).

## Building a backport from source

The supported way to build any branch is in a container. The host needs Docker
and nothing else:

```shell
git clone --branch backports/php-7.4 https://github.com/phillarmonic/php-backports.git
cd php-backports
xdrun docker-build          # builds the image once, then configures and compiles
xdrun docker-test-lang
```

The image carries autoconf, re2c, both bison generations the series need, and
the development headers for the extensions we patch, so a macOS laptop and a
Linux CI runner build the same tree. Objects go to `.build/`, which is
gitignored, and the container runs as your user id, so nothing it writes is
owned by root. Without drun, `.drun/scripts/docker.sh build` runs the same
steps.

### Building on the host

If you would rather build natively, the steps are upstream's:

```shell
./buildconf
./configure --prefix=/opt/php-7.4
make -j"$(nproc)"
make test
sudo make install
```

The build requirements are the same as upstream: autoconf, bison, and re2c for a
minimal build, plus libxml2 and libsqlite3 for a default one.

On Debian and Ubuntu:

```shell
sudo apt install -y pkg-config build-essential autoconf bison re2c libxml2-dev libsqlite3-dev
```

On Fedora:

```shell
sudo dnf install re2c bison autoconf make ccache libxml2-devel sqlite-devel
```

On macOS, with Homebrew:

```shell
brew install autoconf bison re2c libiconv libxml2 sqlite
```

The oldest branches predate current toolchains, and that is the reason the
container exists. It resolves the toolchain half without touching a tree: PHP
5.6 through 7.3 need the bison that still generates the `yystrlen` and
`yystpcpy` helpers for their parser, and the image keeps 3.3.2 beside the
default 3.7, choosing by branch. PHP 5.6 also needs a two-line fix to
`Zend/zend_multiply.h` on ARM, where the AArch64 inline assembly uses a
constraint that modern GCC now satisfies from memory. The branch carries it in
its setup commit, so building 5.6 from the branch needs nothing extra; see
[AGENTS.md](AGENTS.md). On a host build, the branch's own `./configure --help`
is the authority on what it accepts.

If [drun](https://github.com/phillarmonic/drun) is installed, `xdrun build` runs
the same steps with a minimal configuration, and re-runs `buildconf` and
`configure` only when they are needed. `xdrun docker-build` does the same inside
the container. See [the task runner](#the-task-runner) for the rest.

## Container images

Releases are published as source. The tag, its notes, and the history behind it
are the release; there is no tarball and no binary download. What is published
alongside the source is a container image of the build, so a pipeline can
consume a backport without compiling PHP.

```shell
docker run --rm phillarmonic/php-backports:8.1 -r 'echo PHP_VERSION, "\n";'
docker pull phillarmonic/php-backports:7.4
```

Two tags per release:

| Tag | Moves |
| --- | --- |
| `8.1.34` | never; one image, one commit |
| `8.1` | with each release in the series |

Every tag is a manifest for `linux/amd64` and `linux/arm64`. The image is built
from the same toolchain image and the same configure line that produced the
tested build, so it is that build rather than a second one. It carries the CLI
and these extensions:

bcmath, calendar, ctype, curl, dom, exif, fileinfo, filter, ftp, iconv, json,
ldap, libxml, mbstring, mysqli, mysqlnd, opcache, pcntl, pdo with the mysql,
pgsql and sqlite drivers, pgsql, phar, posix, session, simplexml, soap, sockets,
tokenizer, xml, xmlreader, xmlwriter, and zlib.

PHP 5.6 and 7.0 predate OpenSSL 1.1. The toolchain carries 1.1.1, so those two
series ship without `ext/openssl` rather than linked against a TLS library older
than the one php.net archived. Everything else in the list is the same across
the series.

The base is Debian bullseye, the distribution the test suite ran on, which is
what keeps the C library ABI identical to the build. Bullseye is past end of
life, so treat the image as a fixed target for old software, not as a server to
expose without thinking. These are not official PHP releases.

## Testing

Every release is built and tested before it is tagged. To check a branch
yourself:

```shell
xdrun docker-test                            # full suite
xdrun docker-test-ext ext=openssl            # one extension
xdrun docker-test-lang jobs=8                # tests/lang, parallel
xdrun docker-valgrind target=ext/phar        # a target under Valgrind
```

Without the runner, the underlying commands are upstream's:

```shell
make test
make test TESTS="ext/openssl/"
make test TESTS="-j8"                        # run-tests.php -j, 7.2 and later
```

`run-tests.php` takes its options and its test paths in one argument list, and
the Makefile forwards only `TESTS`, so the option has to come first. `-j` does
not exist before 7.2; the container runner detects that and runs serially.

Memory-safety work needs more than a green test run. A debug build with the Zend
allocator disabled under Valgrind finds what a normal run misses:

```shell
./configure --enable-debug
make -j"$(nproc)"
USE_ZEND_ALLOC=0 valgrind --quiet --leak-check=no sapi/cli/php -n path/to/test.php
```

### Continuous integration

GitHub Actions builds and tests every `backports/` branch.
`.github/ci-matrix.tsv` is the support matrix: one row per series and target,
naming the runner, the container platform or the Visual C++ generation, and the
suites to run. The workflow reads it, so adding a platform is a row, not a job.

| Platform | Series | Runs on |
| --- | --- | --- |
| Linux x86_64 | all | `ubuntu-24.04`, the same container `xdrun docker-build` uses |
| Linux aarch64 | all | `ubuntu-24.04-arm`, natively, no emulation |
| Windows x64 and x86 | 7.4, 8.0, 8.1 | `windows-2022`, Visual Studio 2019 toolset |
| Windows x64 and x86 | 7.0 through 7.3 | self-hosted, behind the `win-legacy` marker |

Windows for 5.6 is absent on purpose: `phpsdk_setshell.bat` refuses any toolset
below `vc14`, and the vc11 dependency set survives only in php.net's archive.
Supporting it means building a driver on the pre-2.0 SDK, not adding a row.

Rows behind a marker stay out of the matrix until the marker is enabled, so a
machine that is switched off never leaves a job queued. Enable one with a
`workflow_dispatch` run, or by labelling a pull request `ci:win-legacy`.

Two images exist, and they are not the same thing. The toolchain image is
internal: `ghcr.io/phillarmonic/php-backports-build`, tagged with the hash of
`.drun/docker/`, pulled by every Linux job, and rebuilt once with the Actions
cache when the pull misses. The release image is the product:
`phillarmonic/php-backports` on Docker Hub, described below.

`Tooling parity` runs weekly and fails when `.github/`, `.drun/`, `AGENTS.md`,
or `.gitmessage` differ between `default` and a backport branch. GitHub always
loads a workflow from the commit being built, so those files are copied into
each setup commit, and this check keeps the copies honest.

### The task runner

A [drun](https://github.com/phillarmonic/drun) spec at `.drun/spec.drun` wraps
the commands above so a backport is checked the same way every time. `xdrun` is
a single binary; the spec is plain text and readable without it.

```shell
xdrun doctor                        # can this machine build this branch?
xdrun build                         # configure on demand, then compile
xdrun test                          # full suite
xdrun test-ext ext=standard         # one extension
xdrun test-lang                     # tests/lang
xdrun valgrind target=ext/phar      # a suite target under Valgrind
xdrun valgrind-repro script=repro.php
xdrun lint                          # changed PHP, checked by the branch CLI
xdrun verify-commits                # commit message convention
xdrun verify-identity               # the Phillarmonic line is in php -v
xdrun ci                            # what a branch has to pass

# the same work in the container, with nothing but Docker on the host
xdrun docker-doctor
xdrun docker-build
xdrun docker-test jobs=8
xdrun docker-test-ext ext=session
xdrun docker-test-lang
xdrun docker-lint
xdrun docker-valgrind target=ext/phar
xdrun docker-ci
```

`xdrun --list` shows every task and the parameters it takes. `xdrun configure
flags="..."` replaces the default build, which is the CLI alone
(`--disable-all --enable-cli`); name the extensions a patch touches. Extensions
that take a library use `--with-`, not `--enable-`: `--with-openssl`,
`--with-pgsql`, `--with-ldap`, `--with-libxml`. Under `--disable-all`, SOAP also
needs `--with-libxml` explicitly.

Two things to know before trusting a green run. `xdrun lint` and `xdrun
verify-identity` use the CLI built from the branch, not the PHP installed on the
host, because a modern PHP misreads old syntax. And `xdrun doctor` fails before
a long build when the toolchain cannot work, naming what is missing or too old.
On a modern system the usual gaps are bison 3.0 or newer, since macOS ships 2.3,
and re2c, which several distributions leave out of a minimal install. The
`docker-*` tasks remove both gaps, and they are the ones to reach for unless you
are changing the build system itself.

## Requesting a backport

Backports are requested for vulnerabilities that are already public. Open an
issue with the advisory id, the branch you need, and the upstream commit that
fixes it. The issue template asks for the rest.

Do not send unpublished vulnerabilities here. We cannot run an embargo, and this
repository is not a disclosure channel. [SECURITY.md](SECURITY.md) explains
where reports go.

## Reporting a problem with a backport

A crash, a failed build, or a behavior change introduced by one of our patches
is an ordinary bug. Open an issue with the full `php -v` output, the branch, the
configure line, and a small reproducer. If a patch reopens a vulnerability,
mark the issue clearly and it moves to the front of the queue.

## Contributing

Read [BACKPORTING.md](BACKPORTING.md) for what qualifies, how a patch is adapted,
and what a release needs. The most useful contributions are a missed advisory,
a fix that applies cleanly, a regression test, and a successful build on an old
platform.

[CONTRIBUTING.md](CONTRIBUTING.md), [CODING_STANDARDS.md](CODING_STANDARDS.md),
and the files under `docs/` are upstream PHP documents, kept for reference.
PHP's C style still applies to any patch sent here. The upstream RFC and feature
process does not.

## Further reading

- [PHP manual](https://www.php.net/docs)
- [PHP security advisories](https://github.com/php/php-src/security/advisories)
- [PHP internals documentation](https://php.github.io/php-src/)
- [Upstream php-src](https://github.com/php/php-src)

## License and credits

PHP is distributed under the [Modified BSD License](LICENSE)
(SPDX-License-Identifier: `BSD-3-Clause`). This fork keeps that license, and the
backports are released under the same terms.

### No warranty, no liability

The software is distributed "AS IS", without warranty of any kind, as stated in
the [Modified BSD License](LICENSE). That applies to everything here: the
backport patches, the release tags, and any binary or package built from them.

In plain terms, there is no guarantee that a backport closes a vulnerability,
that it introduces no new bug, that it builds on your platform, or that it stays
compatible with your extensions. Test it before you deploy it. To the extent the
license and applicable law allow, Phillarmonic Software accepts no liability for
damage arising from the use of these builds, including a compromised system,
lost data, or downtime.

### Paid consultancy

These branches are maintained as time allows. If you need a specific fix ported
on a schedule, a build validated on a platform we have not tested, a patch
reviewed before you deploy it, or help planning a migration off an end-of-life
version, Phillarmonic Software takes on paid consultancy for exactly this kind
of work: <https://www.phillarmonic.com/>.

A paid engagement can come with a support agreement. It does not change the
license, it does not make a release an official PHP build, and it does not buy
silence about a bug.

The work in this repository is built on years of effort by the PHP developers
and contributors. See the [PHP credits page](https://www.php.net/credits.php).
The backports, and any mistakes in them, are ours.
