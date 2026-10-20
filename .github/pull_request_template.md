## Change

Describe the change and link the issue it addresses.

## Evidence

List the checks run and their results. Include screenshots for UI changes and call out checks not run.

## Review checklist

- [ ] Scope, acceptance criteria, and relevant documentation are complete; no secrets or production data are included.
- [ ] Tests cover the changed behavior; database changes include a migration and deployment-impact review.
- [ ] Feature/fix PR: target `development`, use a Conventional Commit title (for example `feat: add dataset search`), and squash merge so the title becomes the commit message.
- [ ] Promotion PR: source is this repository's `development`, target is `main`, title follows Conventional Commits (for example `chore: promote development to main`), and use **Create a merge commit**, never squash or rebase. Review the feature commits that release-please will use for versioning.
- [ ] Release PR: opened by the configured release GitHub App against `main`; a human reviews the version and changelog before **Create a merge commit**. This publishes a GitHub release and starts the staging AWS pipeline. Confirm its migration, deployment, and health checks complete before declaring the release deployed; merge `main` back into `development` without squashing to retain release metadata and workflow discovery.

Mark checklist items that do not apply as not applicable in the PR description.
