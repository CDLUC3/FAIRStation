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

The current `RELEASE_PLEASE_TOKEN` was created on 2026-10-21 with a 366-day
expiry, so it expires on **2027-10-22**. Update this note whenever the token is
rotated.

Do not use `GITHUB_TOKEN`: pull requests and releases it creates do not trigger
other workflows. `RELEASE_PLEASE_TOKEN` is a CI secret, not an application
secret; the app runtime still needs only `RAILS_MASTER_KEY`. Do not put it in
Rails credentials: the release workflow must not receive the production master
key.

## Routine release

1. Squash feature PRs into `main`, titled in commit format.
2. Review Release Please's version/changelog PR against `main`; squash-merge it.
   That publishes the release and tag.
3. Publishing the release creates the `v*` tag, which starts the staging
   pipeline. The pipeline triggers on tag pushes only, so branch pushes and
   feature PRs never deploy. There is no GitHub Actions deploy step. Recovery
   after a failed run is a manual pipeline start pinned to that tag's commit.

To reconcile after a transient failure, without inventing a tag:

```sh
gh workflow run release-please.yml --ref main
```

If Release Please's PR conflicts on release files, resolve the conflict on its
branch and prove the resulting tree matches `main` plus the version and changelog
changes; see [git conventions](git_conventions.md).

### Hotfixes

A hotfix follows the same path; there is no separate emergency deploy. Open a
`fix:` PR against `main`, squash-merge it, then squash-merge the release PR it
updates and deploy that release.
