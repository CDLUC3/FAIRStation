# FAIR Station

FAIR Station helps reserve managers connect research context and candidate outputs.

## Stack and commands

Ruby 4.0.6; Rails 8.1; SQLite owned by FAIR Station; server-rendered ERB;
Hotwire (Turbo/Stimulus), importmap, and Propshaft. No Node build step.
Activate `.ruby-version` before running commands.

- `bin/setup --skip-server` — install dependencies and prepare local databases.
- `bin/dev` — start the development server.
- `bin/rails test` — Minitest integration tests.
- `bin/rubocop` — Ruby lint checks.
- `bin/ci` — the full baseline used by GitHub Actions.

## Secrets

Application secrets live in Rails encrypted credentials. Deployment supplies
only `RAILS_MASTER_KEY` (or a mounted `config/master.key`); do not add separate
environment variables for `SECRET_KEY_BASE` or integration keys. CI/tooling
tokens such as `RELEASE_PLEASE_TOKEN` stay in GitHub Actions.

## Read when relevant

- [README](README.md): prerequisites, setup, verification, and release workflow.
- [Git conventions](docs/git_conventions.md): commit, branch, PR, and release rules.
- [GitHub setup](docs/github_setup.md): branch protections and the release token.
- [Architecture decisions](docs/architecture_decisions.md): stack and deferred AWS work.
- [Rails guidelines](docs/rails_guidelines.md): responsibilities, database changes, tests, authorization, and provenance.

Existing `SCHEMA.md` and domain/context documents under `docs/` are exploratory
background, not approved implementation requirements. The research model and
identity provider remain undecided.
