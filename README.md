# FAIR Station

**Connecting fieldwork, data, and research outputs.**

FAIR Station is a community initiative building open infrastructure to connect research at field stations and marine labs with the people, places, data, and outputs that make up the research lifecycle, while advancing shared practices around identifiers, metadata, and research stewardship.

This repository contains the FAIR Station platform.

Learn more at [fairstation.org](https://fairstation.org).

## Application baseline

The application currently serves a public landing page at `/` and a deployment
liveness check at `/up`. Research review, source integrations, and sign-in are
not implemented; the research model and identity provider remain undecided.

The stack is Ruby **4.0.6**, Rails **8.1.4** (locked in `Gemfile.lock`), Puma,
ERB, Hotwire (Turbo and Stimulus), importmap, and Propshaft. SQLite keeps local
development and tests self-contained; AWS production-mode deployments use a
dedicated FAIR Station RDS MySQL database. No database server, Node, Redis, or
RAMS access is needed for local development.

## Local setup

1. Install and activate the Ruby version in `.ruby-version` using your Ruby
   manager. Install Bundler **4.0.19** if unavailable:

   ```sh
   ruby --version
   gem install bundler -v 4.0.19
   bundle --version
   ```

   The `mysql2` gem also needs MySQL client development libraries, even when
   running the SQLite-backed development app. On macOS install `mysql-client`
   and `pkg-config` with Homebrew; if discovery fails, configure Bundler with
   `bundle config set --local build.mysql2 --with-mysql-config="$(brew --prefix mysql-client)/bin/mysql_config"`.
   On Debian/Ubuntu install `default-libmysqlclient-dev`, `build-essential`, and
   `pkg-config`. The production Dockerfile installs its own build/runtime libraries.

   Ruby native extensions require a compiler toolchain (Xcode Command Line Tools
   on macOS or build-essential on Linux). Run commands from the repository root.
   If a shell selects system Ruby, activate your Ruby manager first; with mise,
   prefix commands with `mise exec ruby@4.0.6 --`.

2. Install dependencies and prepare FAIR Station's local databases:

   ```sh
   bin/setup --skip-server
   ```

   This runs Bundler and `bin/rails db:prepare`. It does not reset existing data.
   No master key or external credentials are required for development or tests.
   Keep `DATABASE_URL` unset so Rails uses the dedicated local configuration.

3. Start the app:

   ```sh
   bin/dev
   ```

   Open <http://localhost:3000>. Stop with Ctrl-C. For a different port:
   `bin/dev -p 3100`. Assets are served locally; no frontend build watcher is needed.

## Verify

Run the same baseline used by `.github/workflows/ci.yml`:

```sh
bin/ci
```

It runs setup, RuboCop, Bundler Audit, importmap audit, Brakeman, test database
preparation, Minitest, and Zeitwerk's autoloading check. Dependency audits need
network access. GitHub Actions runs it for pull requests and pushes to `development`
and `main`; the separate `policy` check enforces PR routing and Conventional Commit titles.

For focused checks:

```sh
RAILS_ENV=test bin/rails db:prepare
bin/rails test
bin/rubocop
bin/rails zeitwerk:check
```

With the server running:

```sh
curl --fail http://localhost:3000/
curl --fail http://localhost:3000/up
```

Both should return HTTP 200. In a modern browser, verify the landing page and
check that `/assets/` requests succeed with no JavaScript errors.
`window.Turbo` and `window.Stimulus` should be available in the browser console.
`/up` checks that Rails boots; it does **not** certify database connectivity,
RAMS availability, or readiness of future integrations.

## Configuration and secrets

- `config/database.yml` defines separate local development/test SQLite files and
  a MySQL production connection. All databases belong exclusively to FAIR Station.
  Never configure a RAMS database connection; eventual RAMS access uses its API.
- `.ruby-version` and `Gemfile.lock` pin the toolchain and dependencies.
  `config/environments/` holds environment-specific Rails settings.
  `PORT`, `RAILS_MAX_THREADS`, and `RAILS_LOG_LEVEL` use the Rails/Puma conventions.
- Supply secrets through the environment or Rails encrypted credentials. Production
  requires a stable, private `SECRET_KEY_BASE`, or access to the encrypted
  `secret_key_base` via its matching `RAILS_MASTER_KEY`. Use your deployment secret
  store; never commit keys or put real secrets in example commands.
- `config/credentials.yml.enc` is the generated encrypted credentials file.
  Only edit it with an authorized matching key and `bin/rails credentials:edit`.
  If no shared key exists, coordinate credential provisioning before using it;
  do not silently replace shared credentials.
- `.gitignore` excludes master/credential keys, `.env*`, local databases, logs,
  caches, and compiled assets. `.env` files are **not automatically loaded**.
  Filter sensitive parameters in `config/initializers/filter_parameter_logging.rb`.

## Release and deployment

Feature PRs target `development` with Conventional Commit titles and squash merges.
Promote `development` to `main` with a **merge commit**, never squash or rebase.
Release-please then opens or updates a version/changelog PR against `main`.
Review and merge that PR with a merge commit to publish the GitHub release.
Merge `main` back into `development` through a PR after each release.

Published stable releases trigger the AWS pipeline with the exact released commit.
CodeBuild builds the production image, a one-off ECS task prepares the database,
and ECS deploys the same image. The GitHub workflow reports pipeline submission;
check CodePipeline for migration and deployment success.

- [Architecture decisions](docs/architecture_decisions.md): stack, persistence,
  branch/release model, migration ordering, and secrets boundaries.
- [GitHub setup](docs/github_setup.md): administrator configuration, release App,
  protected branches, and deployment variables.
- [AWS staging setup](infra/README.md): infrastructure inputs, provisioning,
  runtime secrets, deployment, and rollback.

Configuration in the repository does **not** mean AWS staging is deployed.
The deployment requires authorized AWS access and provisioned FAIR Station
resources. Do not reuse RAMS's database, credentials, or application certificate.

The production image runs as a nonroot user on port 3000 behind an HTTPS-terminating
ALB. Inject `SECRET_KEY_BASE`, `RAILS_ALLOWED_HOSTS` (comma-separated hostnames),
and `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USERNAME`,
`DATABASE_PASSWORD` at runtime. A `mysql2://` `DATABASE_URL` is also supported
instead of the separate database fields. Never inject `SECRET_KEY_BASE_DUMMY`
at runtime; it is only used for image-build asset compilation.

Build locally with `docker build -t fairstation:local .`. Run database preparation
as a separate `bin/rails db:prepare` container command; web startup does not migrate.
Configure the ALB health check to request `/up`. Rails logs go to standard output.
Do not expose Puma directly to the internet or store production data on container
disk. No research data or authenticated surface is implemented yet.

## Contributor guidance

Read [AGENTS.md](AGENTS.md) for the short working entrypoint and
[Rails guidelines](docs/rails_guidelines.md) for Rails responsibilities, migrations,
testing, authorization boundaries, and external-source provenance.

Existing `SCHEMA.md` and the domain/context documents under `docs/` are preserved
exploration notes, not an approved schema, identity-provider choice, or description
of implemented features. No domain models or integrations were added by this bootstrap.