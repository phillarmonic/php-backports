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

### Removed

- The upstream `CODEOWNERS` review routing, which would have requested reviews
  from PHP contributors who do not maintain this fork.
- `.github/ISSUE_TEMPLATE/feature_request.yml`, because features are out of
  scope.

### Security

- Nothing has been backported yet. A backport is only published after the
  upstream advisory is public.

[Unreleased]: https://github.com/phillarmonic/php-backports/commits/default
