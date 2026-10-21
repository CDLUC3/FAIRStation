# GitHub setup

## Bootstrap order

1. Land these workflows on `main`. `main` must contain the `checks` and `policy`
   CI jobs before protection can require them.
2. Have a repository administrator run `bin/configure-github --apply`. Preview
   first; the apply step refuses a non-admin account before changing anything.
3. Add the `RELEASE_PLEASE_TOKEN` secret described below.
4. Merge a releasable PR and review the resulting release PR.

AWS deployment is not part of this setup yet. See #31 and
[architecture decisions](architecture_decisions.md).

## Branch and tag protections

`bin/configure-github` configures:

- `main` default; squash only — no merge commits, no rebase.
- `main`: no force push or deletion; PRs require the `checks` and `policy` jobs
  and resolved conversations. No configured bypass actors.
- `v*` tags: creation allowed, update and deletion blocked.

The `policy` job requires every PR to target `main` and use a Conventional
Commit title. Release Please's generated `chore(main): release ...` title passes.
Title edits rerun the check.

## Release token

Release Please needs a token that can open a PR whose CI runs. A token scoped to
one repository is enough:

1. Create a fine-grained PAT for the repository with **Contents**, **Issues**,
   and **Pull requests** read/write.
2. Store it as the Actions secret `RELEASE_PLEASE_TOKEN`.
3. Keep the expiry visible. When it lapses, release PRs stop opening until it is
   replaced.

Do not use `GITHUB_TOKEN`: pull requests and releases it creates do not trigger
other workflows. `RELEASE_PLEASE_TOKEN` is a CI secret, not an application
secret; the app runtime still needs only `RAILS_MASTER_KEY`.

## Routine release

1. Squash feature PRs into `main`, titled in commit format.
2. Review Release Please's version/changelog PR against `main`; squash-merge it.
   That publishes the release and tag.

To reconcile after a transient failure, without inventing a tag:

```sh
gh workflow run release-please.yml --ref main
```

If Release Please's PR conflicts on release files, resolve the conflict on its
branch and prove the resulting tree matches `main` plus the version and changelog
changes; see [git conventions](git_conventions.md).
