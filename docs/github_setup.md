# GitHub setup

## Bootstrap order

1. Land these workflows on `development`, then promote them to `main` with a
   merge commit titled `Release: ...`. Both branches must contain the `checks`
   and `policy` CI jobs before protection can require them.
2. Have a repository administrator run `bin/configure-github --apply`. Preview
   first; the apply step refuses a non-admin account before changing anything.
3. Add the `RELEASE_PLEASE_TOKEN` secret described below.
4. Make a promotion and review the resulting release PR.

AWS deployment is not part of this setup yet. See #31 and
[architecture decisions](architecture_decisions.md).

## Branch and tag protections

`bin/configure-github` configures:

- `development` default; features squash, and a merge commit is allowed for
  syncing `main` back.
- `main`: merge only — never squash. Both promotions and release PRs merge.
- `development` and `main`: no force push or deletion; PRs require the `checks`
  and `policy` jobs and resolved conversations. No configured bypass actors.
- `v*` tags: creation allowed, update and deletion blocked.

The `policy` job accepts `main` PRs only from this repository's `development`
branch or `release-please--branches--main`. Feature PR titles use the
Conventional Commit format. Promotion PRs use `Release: <summary>`; release PRs
use Release Please's generated `chore(main): release ...` title. Title edits
rerun the check.

## Release token

Release Please needs a token that can open a PR whose CI runs. A token scoped to
one repository is enough:

1. Create a fine-grained PAT for the repository with **Contents**, **Issues**,
   and **Pull requests** read/write.
2. Store it as the Actions secret `RELEASE_PLEASE_TOKEN`.
3. Keep the expiry visible. When it lapses, release PRs stop opening until it is
   replaced.

Do not use `GITHUB_TOKEN`: pull requests and releases it creates do not trigger
other workflows.

## Routine release

1. Squash feature PRs into `development`, titled in commit format.
2. Merge `main` into `development` and push, so promotion does not revert release
   metadata.
3. Open a `development` → `main` PR titled `Release: promote development to
   main`. Merge it with a merge commit.
4. Review Release Please's version/changelog PR against `main`; merge it with a
   merge commit. That publishes the release and tag.
5. Merge `main` into `development` again for the next cycle.

To reconcile after a transient failure, without inventing a tag:

```sh
gh workflow run release-please.yml --ref main
```

If Release Please's PR conflicts on release files, resolve them to
`development`'s side and prove the resolution with tree diffs; see
[git conventions](git_conventions.md).
