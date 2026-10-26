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

- `xdrun doctor` comes first on a new machine. System bison is often older than
  3.0 and a build fails late and confusingly without it. Homebrew keeps a
  current bison keg-only; `.drun/scripts/doctor.sh` names what to install.
- `xdrun build` is a minimal build: `--disable-all --enable-cli`. That is
  deliberate for a backport tree. Add the extensions an advisory touches:
  `xdrun configure flags="--disable-all --enable-cli --enable-phar"`.
- `xdrun lint` and `xdrun verify-identity` use the CLI built from the branch,
  never the host's `php`. A host PHP is the wrong grammar for 5.6 and 7.x and
  gives the wrong answer in both directions.
- `xdrun verify-commits` checks the tip commit by default. A whole branch needs
  a range: `xdrun verify-commits range=origin/backports/php-7.4..HEAD`.
- `xdrun ci` is the gate before asking to push. Report the failures it found,
  not the wrapper that produced them.
- The spec must not gain a task that pushes, tags, publishes, or force-pushes.
  Those stay stop-and-ask, on the command line, with a human deciding.

`.drun/` is fork tooling, so each `backports/php-*` branch carries it in its
setup commit together with this file and `.gitmessage`.

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
