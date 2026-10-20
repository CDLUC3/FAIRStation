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

## Read when relevant

- [README](README.md): prerequisites, setup, verification, configuration, and deployment constraints.
- [Rails guidelines](docs/rails_guidelines.md): responsibilities, database changes, tests, authorization, and provenance.

Existing `SCHEMA.md` and domain/context documents under `docs/` are exploratory
background, not approved implementation requirements. The research model and
identity provider remain undecided.
