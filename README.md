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
SQLite, ERB, Hotwire (Turbo and Stimulus), importmap, and Propshaft. SQLite keeps
the bootstrap self-contained; no database server, Node, Redis, or RAMS access is
needed.

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
and `main`; the separate `policy` check enforces PR routing and the title rules
for feature, promotion, and release PRs.

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

- `config/database.yml` defines separate SQLite files under `storage/` for
  development, test, and production. They belong exclusively to FAIR Station.
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

## Workflow and releases

Feature PRs target `development`, use a Conventional Commit title, and squash.
Promotions (`development` → `main`) merge, never squash, and are titled as a
release (`Release: promote development to main`). The merge preserves the
individual commits Release Please reads. Release Please then opens a
version/changelog PR against `main`. Review it and merge it to publish the GitHub
release and tag. Merge `main` back into `development` before the next promotion.

- [Git conventions](docs/git_conventions.md): commit, branch, PR, and promotion rules.
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