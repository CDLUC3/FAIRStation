# Platform architecture decisions

These decisions cover issue [#31](https://github.com/CDLUC3/FAIRStation/issues/31)
and were recorded with the project context in mind. AWS hosting is deliberately
deferred; nothing here claims a deployed environment.

## Application

- **Ruby 4.0.6, Rails 8.1, server-rendered ERB, Hotwire, importmap, Propshaft.**
  Keep one Rails application; no separate frontend build or runtime.
- **SQLite for local development and tests.** It keeps setup self-contained. A
  deployed database choice is undecided; Docker, the production adapter, and the
  AWS environment are deferred until there is a model worth deploying (#30/#32).
- **No background-job backend selected.** No jobs exist. Do not enqueue durable
  work with the in-process default; choose a persistent backend when the first
  import or discovery workflow needs one.
- **No identity provider or research model selected.** The landing page and
  `/up` are the only public surfaces. Do not publish operational or research data
  before authorization exists.

## Branches and releases

- **`development` is the integration and default branch; `main` is released.**
  Feature PRs target `development`; promotions and release PRs target `main`.
- **Feature PR titles use Conventional Commits; promotion titles name the
  release.** Feature PRs squash, so their titles become commit subjects.
  Promotions merge, never squash: the merge preserves the individual commits
  Release Please reads. Title promotions `Release: ...`; do not encode a single
  feature or a version in the title.
- **Do not mix merge and squash promotions.** A squashed promotion leaves its
  original commits only on `development`, so a later merge replays them into
  Release Please's range. This repository is pre-release, so it can adopt merge
  promotions without inherited history.
- **Merge `main` back into `development` before each promotion**, so the
  promotion diff does not revert `version.txt`, `CHANGELOG.md`, or the release
  manifest.
- **Review Release Please's PR before it publishes.** Merging it creates the
  version tag and GitHub release. It is a human gate, not automatic publishing.
- **Both long-lived branches require PRs and CI.** Protect against force pushes
  and deletion; keep `main` merge-only. Details and setup live in
  [GitHub setup](github_setup.md).
- **Release metadata stays on `main`.** Do not cherry-pick or rewrite release
  history; sync `main` into `development` instead.

## Deferred: build and deployment

A production container, a managed database, and the AWS staging pipeline were
developed separately and are not part of this change. When a release first needs
to deploy:

- follow the UC3 CodePipeline → CodeBuild → ECR → ECS Fargate pattern rather than
  introducing a second deployment mechanism;
- build one immutable image per release and deploy that same image, with database
  preparation before the web service starts;
- keep application credentials in AWS, with GitHub-to-AWS access through OIDC
  rather than stored access keys;
- pin deployments to the released commit and image digest, not a mutable tag.

## Reference implementation

The private [UC3 RAMS infrastructure](https://github.com/CDLUC3/ngrams-infrastructure)
provides the operational conventions. FAIR Station must not reuse its database,
credentials, secret namespace, certificate, or service. Separate
[git conventions](git_conventions.md) apply here because FAIR Station keeps
parallel `development` and `main` histories.
