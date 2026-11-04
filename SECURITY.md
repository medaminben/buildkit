# Security policy

## Supported versions

Only the latest `vX.Y.Z` tag on `master` gets security fixes. Products pin a tag
(`BUILDKIT_TAG` in their loader copy, `@vX.Y.Z` on the reusable workflows), so a
fix reaches them when they move their pin.

## Reporting a vulnerability

Please do not open a public issue for security problems. Report them privately through GitHub:
open the [Security tab](https://github.com/medaminben/buildkit/security) and choose
**Report a vulnerability**
([direct link](https://github.com/medaminben/buildkit/security/advisories/new)).

Include what is affected, how to reproduce it, and what an attacker could do with it. You should get
an answer within a week. Once a fix is released, the advisory is published and you are credited
unless you prefer not to be.

## Scope

In scope:
- the loader (`loader/buildkit.cmake`) and `dev_dependency()` (`cmake/Dependency.cmake`), which
  fetch code at configure time;
- the reusable workflows in `.github/workflows/`, which run with the caller's token
  (`release.yml` with `contents: write`);
- the release and manual tools in `tools/`.

buildkit fetches GoogleTest (v1.15.2) when it is not installed. Problems in GoogleTest, or in a
dependency a product declares, belong with their maintainers. If buildkit pins a vulnerable
version, do report that here.
