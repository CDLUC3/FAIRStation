# GitHub release setup

## Bootstrap order

1. Install the release GitHub App and configure its ID/private key below before the
   first workflow-bearing merge into `main`.
2. Land these workflows on `development`, then promote them to `main` with a merge
   commit. Both branches must contain the `checks` and `policy` CI jobs before
   enabling required checks. The `development` branch was created from the existing
   `main`; changing the default branch and protections requires an administrator.
3. Have a repository administrator run `bin/configure-github --apply` after
   reviewing its preview. It makes `development` the default, so future feature
   PRs target it. Existing PRs are not retargeted automatically; review them individually.
4. Provision the separate AWS staging resources in [infra](../infra/README.md),
   then set the staging variables from stack outputs. The first published release
   cannot deploy until these resources and variables exist.
5. Review release-please's generated PR, merge it, and observe the resulting
   release workflow and complete AWS pipeline. Keep #31 open until staging has
   been exercised and the external configuration is verified.

Activate `.ruby-version` before running Ruby scripts. Preview is offline and
prints no secret values:

```sh
bin/configure-github
bin/configure-github --apply
```

The apply command fails before settings mutations unless the authenticated `gh`
user has repository admin permission. It manages only its named rulesets, leaving
unrelated repository/organization rules in place. Re-running updates those named
rulesets and supplied variables. No credential values are read or written.

## Protected branches and tags

`bin/configure-github` configures:

- `development` and `main`: PR required, one approving review, stale approvals
  dismissed, conversations resolved, `checks` and `policy` from GitHub Actions
  required, no force push/deletion, and no configured bypass actors.
- `main`: merge commits only. Both development promotion PRs and release PRs use
  merge commits. Squashing a promotion loses the individual Conventional Commits.
- `development`: squash and merge commits allowed. Squash feature PRs; merge
  back-sync PRs from `main` to preserve ancestry.
- `v*` tags: creation allowed, subsequent update/deletion blocked. Treat published
  release tags as immutable; publish a new version to correct a release.
- Repository: no rebase merging or auto-merge; squash and merge commit titles
  default to the PR title; automatic branch deletion disabled to preserve long-lived branches.
- `staging` environment: deployment refs limited to the `main` branch and `v*`
  tags. Manual retries must select `main`, not the default `development` branch.

The `policy` job permits only same-repository `development` promotions and the
configured release App's release-please branch into `main`. **Every PR title**,
including promotions and release PRs, must follow Conventional Commits. Feature
example: `feat: add research activity import`; promotion example:
`chore: promote development to main`. Title edits rerun the required policy check.
`feat` and `fix` commits drive normal releases; docs/chore-only promotions may not
produce a release. Release-please decides the version from committed history.

## Release GitHub App

Create or select an organization-approved GitHub App installed only on
`CDLUC3/FAIRStation`, with repository permissions:

- Contents: read/write (release PR branch, tags, release)
- Pull requests: read/write (release PR)
- Issues: read/write (release labels)
- Metadata: read (implicit)

No webhook, auto-approval, branch-protection bypass, or AWS credential is needed.
Store the numeric App ID as repository variable `RELEASE_APP_ID`. Store the App's
private PEM key as repository Actions secret `RELEASE_APP_PRIVATE_KEY` using the
GitHub UI or `gh secret set` with standard input from the protected key file.
Do not put the key in this repository, a shell command argument, or build output.

Release-please uses a short-lived installation token. Do not replace it with
`GITHUB_TOKEN`: GitHub suppresses subsequent workflow events from resources created
with that token, which would prevent release PR CI and release-triggered deployment.
The release App must be installed and permitted by organization Actions policies.

## Staging variables and AWS authorization

Set these **environment variables in GitHub's `staging` environment**, not Actions
secrets; none are credentials:

| Variable | Value source |
| --- | --- |
| `AWS_REGION` | Provisioned staging AWS region |
| `AWS_RELEASE_ROLE_ARN` | FAIR Station GitHub OIDC trigger-role stack output |
| `AWS_PIPELINE_NAME` | FAIR Station release-pipeline stack output |

The administration command can create/update them when corresponding environment
variables are supplied to it. It can also set repository variable `RELEASE_APP_ID`.
Omitted variables are left unchanged. Keep application secrets in AWS SSM/Secrets
Manager, not GitHub; see the infrastructure runtime-secret contract.

OIDC role trust must require `aud=sts.amazonaws.com` and
`sub=repo:CDLUC3/FAIRStation:environment:staging`. Its only deployment permission
is starting the dedicated FAIR Station pipeline. The GitHub environment ref policy
and release validation are part of this authorization boundary.

## Routine releases and recovery

1. Squash feature PRs into `development` using Conventional Commit titles.
2. Open a `development` → `main` PR titled `chore: promote development to main`;
   review and merge with `--merge`. Release-please reads the preserved feature
   commits, not just this promotion title.
3. Review the App's version/changelog PR against `main`; merge with `--merge`.
4. Confirm the GitHub release and the deployment workflow's pipeline execution ID.
   A green GitHub submission job is **not** proof of a successful AWS rollout.
5. Inspect Source, Build, Migrate, and Deploy in CodePipeline; verify the staging
   URL and image digest before treating the release as deployed.
6. Open a `main` → `development` PR titled `chore: sync released version`; merge
   with `--merge`, never squash. This carries release metadata into development.

To reconcile release-please after a transient failure, without inventing a tag:

```sh
gh workflow run release-please.yml --ref main
```

To retry deployment of an existing published release, set `RELEASE_TAG` to that
release's `vMAJOR.MINOR.PATCH` tag, then run:

```sh
gh workflow run deploy-release.yml --ref main -f tag="$RELEASE_TAG"
```

The workflow rejects draft/prerelease releases, invalid tags, tags outside `main`
history, and manual runs from other branches. AWS queues complete executions to
avoid overlapping migration/deploy stages. Retrying an older release intentionally
rolls application code back; it does not undo database changes. Check migration
compatibility before doing so.
