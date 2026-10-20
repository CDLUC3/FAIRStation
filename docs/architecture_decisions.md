# Platform architecture decisions

These decisions cover issue [#31](https://github.com/CDLUC3/FAIRStation/issues/31),
not the exploratory research schema. AWS resources and GitHub settings require
separate provisioning; committed configuration is not evidence of a live deployment.

## Application and persistence

- **Ruby 4.0.6, Rails 8.1, server-rendered ERB, Hotwire, importmap, Propshaft.**
  Keep one Rails application and avoid a separate frontend build/runtime.
- **SQLite for development and tests; dedicated RDS MySQL for AWS.** Local setup
  stays self-contained. MySQL matches the existing UC3 ECS infrastructure, while
  Fargate tasks remain disposable. FAIR Station owns its database and credentials;
  RAMS integration must use the RAMS API, never its database. Adapter-specific SQL
  and migrations need verification against MySQL before release; SQLite tests alone
  cannot establish production compatibility.
- **No background-job backend selected.** There are no implemented jobs. Do not
  enqueue durable work using the in-process Rails default. Select and provision a
  persistent backend when the first import/discovery workflow needs it; no Redis
  or worker service is provisioned speculatively.
- **No identity provider or research model selected.** Deployment does not authorize
  exposing future operational or research data. The landing page and liveness probe
  are the only current public surfaces.

## Branches and releases

- **`development` is the integration/default branch; `main` is the release line.**
  All PR titles follow Conventional Commits. Feature PRs target `development`
  and squash merge. Promotion PRs use `chore: promote development to main` and
  merge commits, never squash or rebase: release-please needs the individual
  feature commit history to calculate versions.
- **Review release-please's generated PR before publishing.** A promotion updates
  the release PR; merging that PR into `main` creates the version tag, changelog,
  and GitHub release. This is an explicit release gate, not automatic publishing
  for every promotion. Merge release PRs with a merge commit too.
- **Use a dedicated GitHub App installation token for release-please.** Releases
  and PRs created with the repository `GITHUB_TOKEN` do not trigger subsequent
  workflows. The App token allows normal PR checks and the release-published
  deployment event without a personal token. The App gets no branch-protection
  bypass; a human reviews its PR.
- **Both long-lived branches require PRs, approval, and CI.** Protect against
  deletion and force pushes. `main` permits merge commits only. After each release,
  merge `main` back into `development` through a PR to carry version/changelog
  changes forward; do not cherry-pick or rewrite release history.

## Build and deployment

- **GitHub orchestrates releases; AWS builds and deploys.** Follow the UC3
  CodePipeline → CodeBuild → ECR → ECS Fargate pattern instead of introducing a
  second AWS deployment mechanism. Only a published, non-prerelease GitHub release
  on the `main` history can start the staging release workflow. Branch pushes do
  not start the AWS pipeline.
- **Pin deployments to the released commit and image digest.** Pass the resolved
  release SHA to CodePipeline's `SourceAction`; do not build whichever commit is at
  `main` when the build begins. Build one image, run database preparation with that
  image, and deploy that same image. Do not deploy mutable `latest` tags.
- **Separate migration and web startup.** Run database preparation as a one-off ECS
  task and require its successful exit before updating the service. Web replicas
  must not race to migrate. Schema changes must remain compatible with the previous
  web revision during rollout; application rollback does not roll back a migration.
- **HTTPS terminates at the ALB.** Rails assumes the trusted HTTPS proxy, restricts
  accepted application hosts, and exposes `/up` for liveness. `/up` is not a
  database readiness test. Public requests must not reach the container directly.

## Credentials and operations

- **GitHub-to-AWS uses OIDC, not stored AWS access keys.** Restrict the IAM trust to
  this repository's `staging` environment and the STS audience. The release role
  may start only the FAIR Station pipeline; it does not administer infrastructure.
- **Application credentials stay in AWS.** Use an isolated FAIR Station SSM
  namespace for runtime secrets and a dedicated generated Secrets Manager secret
  for RDS credentials. ECS injects secrets through its task execution role. Never put live
  secrets in image layers, build arguments, repository variables, or CI output.
  Future RAMS and Zotero credentials belong in the same environment-specific secret
  boundary, with explicit task-definition mappings when those integrations exist.
  Database credential rotation is operator-controlled and must update the database
  and roll the ECS tasks together; automatic rotation without task refresh would
  leave running containers with stale passwords.
- **Independent state lifecycle.** Database backups and deletion protection are
  independent of application releases. CloudWatch collects application/build logs.
  Before declaring staging ready, verify the deployed URL, secrets injection,
  database connectivity, backup/restore procedure, and operational ownership.

## Reference implementation

The private [UC3 RAMS infrastructure](https://github.com/CDLUC3/ngrams-infrastructure)
provides the operational conventions. FAIR Station does not reuse its database,
service, secret namespace, or application-specific certificate. Existing network,
DNS, and connection resources must be verified in the target AWS account.
