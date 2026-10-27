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
MySQL **8.4**, ERB, Hotwire (Turbo and Stimulus), importmap, and Propshaft. MySQL
runs in every environment — the same engine as the deployed RDS instance — so SQL
differences surface locally instead of in staging. Docker supplies the local
server; no Node, Redis, or RAMS access is needed.

## Local setup

1. Install and activate the Ruby version in `.ruby-version` using your Ruby
   manager. Install Bundler **4.0.19** if unavailable:

   ```sh
   ruby --version
   gem install bundler -v 4.0.19
   bundle --version
   ```

   Ruby native extensions require a compiler toolchain (Xcode Command Line Tools
   on macOS or build-essential on Linux). Run commands from the repository root.
   If a shell selects system Ruby, activate your Ruby manager first; with mise,
   prefix commands with `mise exec ruby@4.0.6 --`.

2. Install dependencies, start MySQL, and prepare FAIR Station's local databases:

   ```sh
   bin/setup --skip-server
   ```

   This runs Bundler, starts the MySQL server defined in `compose.yml` (or uses a
   server already listening on the configured host and port), and runs
   `bin/rails db:prepare`. It does not reset existing data. No master key or
   external credentials are required for development or tests. Docker must be
   running for the default setup; set `DATABASE_HOST`, `DATABASE_PORT`,
   `DATABASE_USERNAME`, and `DATABASE_PASSWORD` to use a different server.

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
network access. GitHub Actions runs it for pull requests and pushes to `main`;
the separate `policy` check enforces the target branch and Conventional Commit
titles.

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

- `config/database.yml` defines separate MySQL databases
  (`fair_station_development`, `fair_station_test`) that belong exclusively to
  FAIR Station. Never configure a RAMS database connection; eventual RAMS access
  uses its API. Development and test read non-secret coordinates from the
  environment; production reads its password from Rails credentials, never from
  an environment variable.
- `.ruby-version` and `Gemfile.lock` pin the toolchain and dependencies.
  `config/environments/` holds environment-specific Rails settings.
  `PORT`, `RAILS_MAX_THREADS`, `RAILS_LOG_LEVEL`, and the non-secret database
  coordinates `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, and
  `DATABASE_USERNAME` are non-secret operational settings.
- **Application secrets live in Rails encrypted credentials.**
  `config/credentials.yml.enc` already contains `secret_key_base`; production
  reads it using `RAILS_MASTER_KEY`. The deployment therefore supplies only the
  master key (set `RAILS_MASTER_KEY`, or mount `config/master.key` read-only).
  Do not add `SECRET_KEY_BASE` or integration keys as separate environment
  variables.
- Edit shared credentials with `bin/rails credentials:edit`, or production-only
  credentials with `bin/rails credentials:edit --environment production`. Commit
  the `.enc` files; never commit `config/master.key` or
  `config/credentials/*.key`. If no shared key exists, coordinate provisioning;
  do not silently replace shared credentials.
- **Error reporting is Honeybadger**, configured in `config/honeybadger.yml`. Its
  API key is an application secret: it is stored in Rails encrypted credentials
  as `honeybadger_api_key`, not in an environment variable. Development and test
  use Honeybadger's null backend, so no report leaves a local process. If the key
  is absent, production logs `API key is missing` and drops notices instead of
  failing a request. Insights performance events are disabled; only exceptions
  from deployed environments are reported.
- Future RAMS, Zotero, ORCID, and managed-database credentials belong in the same
  encrypted store under namespaced keys, read with
  `Rails.application.credentials.dig(...)`. This keeps one runtime secret instead
  of spreading access across environment variables and provider-specific stores.
- `RELEASE_PLEASE_TOKEN` is a GitHub Actions secret for release automation, not
  an application secret; it does not change the runtime master-key requirement.
  Do not put it in Rails credentials: the release workflow must not receive the
  production master key.
- `.gitignore` excludes master/credential keys, `.env*`, local databases, logs,
  caches, and compiled assets. `.env` files are **not automatically loaded**.
  Filter sensitive parameters in `config/initializers/filter_parameter_logging.rb`.

## Workflow and releases

Feature PRs target `main`, use a Conventional Commit title, and squash. Release
Please watches `main` and opens a version/changelog PR; review it and squash-merge
it to publish the GitHub release and tag. There is no separate integration branch.

- [Git conventions](docs/git_conventions.md): commit, branch, PR, and release rules.
- [GitHub setup](docs/github_setup.md): protections, release token, and release steps.
- [Architecture decisions](docs/architecture_decisions.md): stack and branch decisions.

AWS deployment is deferred. There is no production container or deployed
environment; publishing a release currently changes no runtime. The build and
deploy design is recorded in the deferred section of the architecture decisions.

## Contributor guidance

Read [AGENTS.md](AGENTS.md) for the short working entrypoint and
[Rails guidelines](docs/rails_guidelines.md) for Rails responsibilities, migrations,
testing, authorization boundaries, and external-source provenance.

Existing `SCHEMA.md` and the domain/context documents under `docs/` are preserved
exploration notes, not an approved schema, identity-provider choice, or description
of implemented features. No domain models or integrations were added by this bootstrap.