# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Version numbers are PHP's, continued past the last upstream release: `7.4.34`
is the next 7.4 build, not a separate project version. Semantic Versioning does
not apply here, because the interface is PHP's and the numbers follow its patch
sequence.

Releases are tagged on their `backports/php-X.Y` branch. This file lives on
`default` and indexes them, newest first, naming every advisory by CVE. See
[BACKPORTING.md](BACKPORTING.md) for how a release is cut.

## [Unreleased]

### Added

- `BACKPORTING.md`, covering what qualifies for a backport, how a fix is
  adapted, what testing is required, and how a release is cut.
- Build identity policy: every backport reports Phillarmonic Software in
  `php -v` and `phpinfo()`, and states separately that it is not an official PHP
  release.
- A backport request issue template that asks for the advisory, the branch, and
  the upstream fix.
- README sections for coverage, branch layout, version numbering, warranty and
  liability, and paid consultancy.
- A `.gitmessage` template and the commit message convention in `AGENTS.md`.
- A drun spec at `.drun/spec.drun` covering configure, build, test, and
  Valgrind runs, changed-file syntax checks, changelog promotion, and a
  commit-message check that enforces the convention above. `README.md`,
  `AGENTS.md`, and `BACKPORTING.md` describe the tasks and when to use them.
- Container builds. `.drun/docker/Dockerfile` and `.drun/scripts/docker.sh` build
  and test the checked-out branch with nothing on the host but Docker, exposed
  as `docker-*` tasks that mirror the host ones. The image carries the autoconf,
  re2c, and both bison generations the series need, keeps the build out of tree
  in `.build/`, and runs as the host user. Bullseye is past end of life, so the
  image pins apt at `archive.debian.org`, where the pool is still complete.
- Continuous integration in place of php-src's workflows.
  `.github/workflows/build.yml` builds and tests a `backports/` branch on Linux
  x86_64 and aarch64 and on Windows x64 and x86, driven by the support matrix
  in `.github/ci-matrix.tsv`. Rows behind a marker, such as `win-legacy`, stay
  out of the matrix until the marker is enabled.
- `.github/workflows/image.yml` publishes the container image for both
  architectures to GHCR, tagged with the hash of `.drun/docker/`.
- `.github/workflows/parity.yml` fails when the tooling that travels with each
  backport branch drifts from `default`.
- A runtime image per release: `phillarmonic/php-backports` on Docker Hub, tagged
  with the version and the series and published for amd64 and arm64 from the
  tagged commit. `.drun/scripts/build-php-image.sh` builds it through the same
  toolchain image and configure line the test suite used, and
  `.github/workflows/release-image.yml` publishes it on a `php-*` tag. PHP 5.6
  and 7.0 ship without `ext/openssl`, which does not compile against the
  OpenSSL 1.1 in the toolchain.

### Changed

- `README.md` rewritten around the mission and the supported series: PHP 5.6,
  7.0 through 7.4, 8.0, and 8.1.
- `SECURITY.md` no longer presents this repository as a vulnerability disclosure
  channel. Unpublished reports go to the PHP project; backport requests for
  public advisories are handled here.
- `AGENTS.md` and `CONTRIBUTING.md` now describe this fork's rules instead of
  upstream's RFC and feature process.
- Upstream documents under `docs/` carry a banner saying they are reference
  material, not documentation of this fork.
- Repository URLs point at `phillarmonic/php-backports`.
- A backport branch's setup commit now carries `.github/` as well as `.drun/`,
  `AGENTS.md`, and `.gitmessage`.
- Releases carry source only. The container image is the compiled artifact, so
  no tarball, Windows zip, or other binary download is produced.

### Removed

- The upstream `CODEOWNERS` review routing, which would have requested reviews
  from PHP contributors who do not maintain this fork.
- `.github/ISSUE_TEMPLATE/feature_request.yml`, because features are out of
  scope.
- Upstream's GitHub Actions tree: `test.yml`, `test-suite.yml`, `matrix.php`,
  the composite actions, the Windows build scripts, and the tag-driven
  `windows-builds.yml` that dispatched to `php/php-windows-builder`. None of it
  matched `backports/` branches or this fork's hardware.

### Fixed

- The test tasks set `REPORT_EXIT_STATUS=1`. `run-tests.php` reads it to decide
  its exit code, so without it the suite printed a failure summary and still
  exited 0, and a green task proved nothing. The identity check had the
  companion bug: it grepped the two banner strings out of one pipeline, where
  the first grep drops the line the second one needs.

### Security

- Nothing has been backported yet. A backport is only published after the
  upstream advisory is public.

[Unreleased]: https://github.com/phillarmonic/php-backports/commits/default
