# GitHub setup

## Bootstrap order

1. Land these workflows on `main`. `main` must contain the `checks` and `policy`
   CI jobs before protection can require them.
2. Have a repository administrator run `bin/configure-github --apply`. Preview
   first; the apply step refuses a non-admin account before changing anything.
3. Configure the release GitHub App credentials described below.
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

Release Please uses a short-lived GitHub App installation token so its release
PRs can trigger CI without depending on a personal access token.

1. Register a GitHub App with **Contents**, **Issues**, and **Pull requests**
   read/write repository permissions. Webhooks and user authorization are not
   needed. For a personally owned pilot app installed on this organization,
   select **Any account** as the installation option.
2. Install the app on the organization with access limited to FAIRStation.
   Organization approval may be required.
3. In repository **Settings → Secrets and variables → Actions**, add the app's
   client ID as the repository variable `RELEASE_APP_CLIENT_ID`.
4. Generate an app private key and store the complete PEM contents as the
   repository Actions secret `RELEASE_APP_PRIVATE_KEY`.

The release workflow generates a token scoped to the current repository with
the three write permissions above. The token action revokes it when the job
finishes. Never commit the private key or put it in Rails credentials; the app
runtime still needs only `RAILS_MASTER_KEY`.

Keep the existing `RELEASE_PLEASE_TOKEN` secret during the pilot so reverting
the workflow restores PAT authentication. Remove it after confirming that the
app can create or update release PRs, their CI runs, and a planned release
publishes successfully. If the PAT serves other workflows or repositories,
check those consumers before revoking it. Transfer the pilot app to the
organization after verification.

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

### Hotfixes

A hotfix follows the same path; there is no separate emergency deploy. Open a
`fix:` PR against `main`, squash-merge it, then squash-merge the release PR it
updates and deploy that release.
