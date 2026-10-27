# Platform architecture decisions

These decisions cover issue [#31](https://github.com/CDLUC3/FAIRStation/issues/31)
and were recorded with the project context in mind. AWS hosting is deliberately
deferred; nothing here claims a deployed environment.

## Application

- **Ruby 4.0.6, Rails 8.1, server-rendered ERB, Hotwire, importmap, Propshaft.**
  Keep one Rails application; no separate frontend build or runtime.
- **MySQL 8.4 in every environment.** Development, test, CI, and the deployed
  RDS instance run the same engine, so SQL mode, collation, and column behavior
  match; a SQLite/MySQL split hides deployment-only failures. Local development
  runs MySQL from `compose.yml`, and `bin/setup` starts it. The deployed
  environment itself remains deferred until there is a model worth deploying
  (#30/#32).
- **Rails encrypted credentials are the application secrets boundary.** Keep
  `secret_key_base`, future RAMS/Zotero/ORCID credentials, and managed-database
  credentials in `config/credentials.yml.enc` or environment-specific
  credentials. The runtime deployment supplies only `RAILS_MASTER_KEY`; do not
  spread application secrets across environment variables or provider-specific
  stores. CI/tooling tokens such as `RELEASE_PLEASE_TOKEN` remain GitHub Actions
  secrets, not application configuration.
- **Honeybadger is the error-reporting service.** Exceptions from deployed
  environments are reported; development and test use its null backend.
  `config/honeybadger.yml` reads the API key from Rails encrypted credentials
  (`honeybadger_api_key`), consistent with the secrets boundary above, and
  Insights performance events stay disabled.
- **No background-job backend selected.** No jobs exist. Do not enqueue durable
  work with the in-process default; choose a persistent backend when the first
  import or discovery workflow needs one.
- **No identity provider or research model selected.** The landing page and
  `/up` are the only public surfaces. Do not publish operational or research data
  before authorization exists.

## Branches and releases

- **`main` is the trunk and the released branch.** Feature PRs target `main` and
  squash; there is no long-lived integration branch.
- **All PR titles use Conventional Commits.** A squash merge turns the title
  into the commit subject Release Please reads. Release Please's own release PR
  uses `chore(main): release ...`.
- **Review Release Please's PR before it publishes.** Squash-merging it creates
  the version tag and GitHub release. It is a human gate, not automatic
  publishing.
- **`main` requires PRs and CI.** Protect against force pushes and deletion;
  keep `main` squash-only. Details and setup live in
  [GitHub setup](github_setup.md).
- **Release metadata stays on `main`.** Do not cherry-pick or rewrite release
  history.

## Deferred: build and deployment

The production container is defined by `Dockerfile` and `bin/docker-entrypoint`;
nothing here claims a deployed environment. The managed database, the AWS
staging pipeline, and DNS remain deferred. When a release first needs to deploy:

- follow the UC3 CodePipeline → CodeBuild → ECR → ECS Fargate pattern rather than
  introducing a second deployment mechanism;
- build one immutable image per release and deploy that same image, with database
  preparation before the web service starts;
- let AWS pull source through a CodeConnections GitHub app and start the pipeline
  from the `v*` release tag, so the tag is the deployment gate and GitHub needs
  no AWS credentials;
- keep `RAILS_MASTER_KEY` the only secret the service receives. Application
  secrets, including the database password and later RAMS and Zotero keys, stay
  in Rails encrypted credentials.

## Reference implementation

The private [UC3 RAMS infrastructure](https://github.com/CDLUC3/ngrams-infrastructure)
provides the operational conventions. FAIR Station must not reuse its database,
credentials, secret namespace, certificate, or service. Separate
[git conventions](git_conventions.md) apply here because FAIR Station releases
from a single `main` history with Release Please.
