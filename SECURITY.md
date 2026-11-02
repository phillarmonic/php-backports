# Security policy

## This is not a disclosure channel

Do not send us vulnerabilities that are not public yet. This repository has no
embargo process, no CNA, and no way to coordinate a release with the PHP
project. A report sent here could sit unread while the bug is still private
everywhere else.

Report a new PHP vulnerability to the PHP project:

- <https://github.com/php/php-src/security/advisories/new>
- <security@php.net>

Their classification rules decide what counts as a vulnerability, and they
decide when it becomes public. The full policy is at
<https://github.com/php/policies/blob/main/security-classification.rst>.

We are not the PHP project, and a report to them does not oblige us to backport
anything.

## What this repository does

Once an advisory is public, we port the fix to the `backports/php-*` branches and
release it with a written note of which advisories it contains. Nothing is
published before the advisory and the upstream fix are public.

## Requesting a backport

Open an issue using the backport request template
(<https://github.com/phillarmonic/php-backports/issues/new/choose>) and include:

- the CVE or advisory id, with a link;
- the branch you need, for example `php-7.4`;
- the upstream commit, pull request, or patch that fixes it;
- how the vulnerable code is reached, if that is not obvious;
- whether you can test a build, and on what platform.

Requests are prioritized by severity and reachability. Memory corruption
reachable from untrusted input comes first. A public exploit moves a request
up. A missing advisory does not: if the issue is still private, we cannot act
on it.

## What we do not do

- Backport fixes for problems that are not security issues, or that PHP's own
  policy classifies as out of scope.
- Ship a fix privately or ahead of the upstream advisory.
- Pay for vulnerability reports or run a bounty.
- Promise a date. This is maintenance work done around other jobs.

Donations fund maintenance time. They do not buy priority, a private fix, or
influence over what gets ported. Paid consultancy is a separate arrangement,
described in the README.

## Bugs in a backport

A crash, a build failure, or a regression caused by one of our patches is a
normal bug. Open an issue with the full `php -v` output and a reproducer.

If a backport turns out to reopen a vulnerability, say so plainly in the issue.
That is treated as urgent, and the release note for the affected tag gets
corrected.
