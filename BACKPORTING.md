# Backporting a security fix

This is the working procedure for the `backports/php-*` trees. It is written for
whoever cuts the release, but a patch sent from outside should follow the same
shape.

## 1. Pick a fix that qualifies

A fix is a candidate when all of these hold:

- it is **public**: an advisory, an upstream commit, or an upstream release
  contains it;
- it closes a serious vulnerability: memory corruption reachable from untrusted
  input, remote code execution, authentication bypass, a sandbox or
  `open_basedir` escape where the fix is contained;
- it applies without dragging unrelated upstream work along.

Out of scope, even when a CVE was assigned:

- resource exhaustion that only kills the request that caused it;
- `open_basedir` and `disable_functions` bypasses;
- malformed input to an API that is documented as unsafe, including
  `unserialize()` used as a trust boundary;
- bugs that need the attacker to run code in the process already.

`SECURITY.md` points at PHP's own classification for the gray areas. When in
doubt, ask before spending a day on the port.

### Where to find candidates

- the [php-src security advisories](https://github.com/php/php-src/security/advisories)
  and the [PHP changelogs](https://www.php.net/ChangeLog-8.php), which name the
  CVEs fixed in each release
- fixes merged into the newest PHP branches that name a CVE or an advisory
- distribution security trackers: Debian, Ubuntu, Red Hat, SUSE, Alpine. For
  5.6 and 7.x these are the most useful source, because those distributions
  already did the adaptation work for their own packages. Read their patch, then
  produce ours from the upstream commit, not the other way around.

## 2. Start from the last upstream release

Each backport branch is cut once, from the final upstream release tag of that
series. Upstream refs stay untouched.

```shell
git fetch origin
git switch --create backports/php-7.4 php-7.4.33
# one Fork: commit sets the branch up; see below
git switch --create backport/CVE-2024-12345 backports/php-7.4
```

A new `backports/` branch starts with one `Fork:` commit that sets it up, for
7.4 `Fork: set up backports/php-7.4`. That commit carries the identity patch
from section 5 and the fork's tooling: `AGENTS.md`, `.gitmessage`, and `.drun/`.
They live on the repository default, so copy them from a `default` checkout
rather than retyping them. Every advisory branch is then cut from the current
`backports/` head. Work happens on a short-lived branch named for the advisory
and is merged back. Never commit to `PHP-7.4` or to `master`.

Some upstream branch heads already claim the next patch level with a `-dev`
suffix (`7.4.34-dev`). That is the number to release. Clear the suffix, do not
invent a new one.

## 3. Adapt, do not transplant

Cherry-pick with provenance, then fix it up:

```shell
git cherry-pick -x <upstream-sha>
```

Commit messages follow [AGENTS.md](AGENTS.md). Enable the bundled template with
`git config commit.template "$(git rev-parse --show-toplevel)/.gitmessage"`.

The goal is the smallest change that removes the bug. In practice:

- keep the bounds check, the reference count fix, or the type validation;
- drop the surrounding refactor, renaming, or cleanup that came with it;
- do not add public API, new constants, or new ini settings;
- 5.6 has no `zend_string` and uses error handling from before PHP 7. The 7.x
  branches have `zend_string` but not the helpers that appeared in 8.x. Write
  the check in the idioms of that branch;
- when a later branch introduced a helper the fix depends on, inline the
  smallest equivalent instead of porting the helper;
- leave unrelated code alone, even when it is ugly. Every extra line is a line
  someone has to trust.

If the fix cannot be expressed without a large rewrite, say so on the request
and leave it open. A wrong patch is worse than a missing one.

## 4. Test it

Every backport carries a regression test. Start from the upstream `.phpt`, adapt
`skipif`, the expected output, and the extension requirements to the branch.

The drun tasks in `.drun/spec.drun` run the same commands with the parameters a
backport needs:

```shell
xdrun doctor                        # toolchain, branch, tree version
xdrun build                         # minimal build, configured on demand
xdrun test-ext ext=standard         # the touched extension
xdrun test-lang                     # tests/lang
xdrun lint                          # changed PHP, checked by this branch's CLI
```

`make` still works when `xdrun` is not installed:

```shell
make test TESTS=ext/standard/tests/strings/
make TEST_PHP_ARGS=-j4 test
```

For memory-safety fixes, also run the reproducer under a debug build with the
Zend allocator off:

```shell
./configure --enable-debug
make -j"$(nproc)"
USE_ZEND_ALLOC=0 valgrind --quiet --leak-check=no sapi/cli/php -n repro.php
```

`xdrun configure-debug` and `xdrun build` produce that build, and `xdrun
valgrind-repro script=repro.php` runs the last command against it. A whole suite
target under Valgrind is `xdrun valgrind target=ext/phar`.

An AddressSanitizer build is worth it for use-after-free and out-of-bounds
work, but Valgrind is enough to catch the common cases on the oldest branches.

Record what was tested in the pull request: branch, platform, extensions built,
and the commands run. A test that was skipped is reported as skipped, not as
green.

## 5. Make the build identify itself

Every `backports/` branch carries the same small patch, applied before any
security work, so a plain `./configure && make` produces a binary that cannot be
mistaken for an official PHP release.

The `-v` output is printed in `sapi/cli/php_cli.c`, in the `php_printf("PHP %s
(%s) ...` call. Add one line after the copyright line:

```text
Built by Phillarmonic Software (https://www.phillarmonic.com/) - security backport, not an official PHP release
```

Add the same information to the phpinfo version block in `main/main.c`, next to
the `PHP Version` row, as `Backport`. Update `sapi/cli/tests/001.phpt`, which
asserts the shape of the `-v` output, or the branch's test suite fails on the
patch itself.

The copyright line stays verbatim. The code is the PHP developers' work; the
fork only adds its own line below it.

`xdrun verify-identity` checks a built binary for the line, and is the quickest
way to confirm the patch survived a rebase.

`PHP_BUILD_PROVIDER` and `php_get_version()` exist on current PHP but not on
5.6 through 8.1, so this is a per-branch patch rather than a configure flag.
Keep it byte-identical across branches apart from the surrounding code style,
so it is easy to recognize in a diff.

## 6. Cut a release

1. Set the version in `PHP_MAJOR_VERSION`, `PHP_MINOR_VERSION`, and
   `PHP_RELEASE_VERSION`: in `configure.ac` from 7.2 on, in `configure.in`
   before that. From 7.4 on, the `AC_INIT` version has to match. Clear
   `PHP_EXTRA_VERSION` (`-dev`, `-rc1`) for a release.
2. Build from a clean tree and run the full suite: `xdrun rebuild`
   followed by `xdrun test`, or the equivalent `make` commands.
3. Tag on the `backports/` branch, in upstream's form: `php-7.4.34`.
4. Write release notes listing each advisory by CVE and the upstream commit it
   came from. Say which extensions are touched.
5. Publish only after the upstream advisory is public. If the advisory is still
   under embargo, the work sits on the branch and waits. Once it is public, add
   the release to `CHANGELOG.md` on `default`, under its version heading, naming
   each CVE it fixes. `xdrun changelog version=7.4.34` promotes the Unreleased
   section for you when it holds nothing but this release; with entries from two
   series mixed together, write the heading by hand.

## Checklist

- [ ] advisory is public, and the upstream fix is identified
- [ ] branch cut from the last upstream release tag
- [ ] identity patch present and `php -v` verified (`xdrun verify-identity`)
- [ ] patch keeps the check and drops the refactor
- [ ] regression test adapted from upstream and passing
- [ ] touched extension suite and `tests/lang` pass (`xdrun test-ext`,
      `xdrun test-lang`)
- [ ] Valgrind or ASan run for memory-safety fixes
- [ ] `xdrun ci` green on the branch tip
- [ ] version set, `-dev` cleared
- [ ] tag and release notes name every CVE
- [ ] nothing published before the advisory
