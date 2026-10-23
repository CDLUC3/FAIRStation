# Rails conventions

FAIR Station is a server-rendered Rails application with its own database.
Keep the foundation independent of the research model and identity provider;
neither is selected by the existing exploratory schema/context documents.

## Responsibilities

- Controllers handle HTTP, permitted parameters, authorization, and responses.
  Prefer RESTful resources as workflows emerge, not a separate frontend/API.
- Keep persistence and invariants in Active Record models when actual requirements
  justify models. Extract cohesive Ruby objects for demonstrated complexity, not
  speculative services, operation frameworks, or empty namespaces.
- Keep queries and business calculations out of ERB. Use helpers for formatting
  and partials with explicit locals for repeated markup; add presenters only when needed.
- Prefer Turbo for navigation and forms, Stimulus for small browser behaviors.
  Return HTTP 422 for invalid form submissions and use redirects after successful writes.
  Importmap and Propshaft serve assets without a Node build pipeline.
- Limit callbacks to record integrity. Make external calls and other side effects
  explicit rather than hiding them in persistence callbacks.

## Database changes

- FAIR Station owns separate development, test, and production MySQL databases.
  RAMS access must eventually use its API, never its database or credentials.
  Local development uses the same engine version as deployment, started by
  `bin/setup` from `compose.yml`. `database.yml` does not read `DATABASE_URL`.
- Generate migrations with `bin/rails generate migration`; commit migrations and
  the generated `db/schema.rb` once there is a schema. Do not hand-edit schema dumps
  or translate the exploratory `SCHEMA.md` into tables without an approved requirement.
- Use constraints, indexes, defaults, and model validations to protect real invariants.
  Use transactions with bang writes or explicit failure handling for atomic changes.
- Review migrations for existing data, locking, and recoverability. Do not rewrite
  migrations already deployed; destructive changes require an explicit rollout plan.
- Paginate growing lists and avoid N+1 queries. MySQL runs the same version in
  development and deployment, so migrations must be valid against RDS; changing
  engines is an explicit infrastructure decision.

## Tests and verification

- Use Rails Minitest: model/PORO tests for behavior and integration tests for HTTP,
  authorization, and failure responses. Keep fixtures minimal and setup local.
- Test observable outcomes, boundaries, and meaningful failures, not private methods,
  exact page prose, or implementation wiring. Prefer a failing regression before a bug fix.
- Add browser tests when interactions warrant them; no system-test driver is installed
  in this foundation. Smoke-test changed pages in a real browser, including Hotwire,
  keyboard access, and narrow layouts.
- Stub external HTTP at its boundary when integrations arrive; no automatic network
  blocking library is installed. Tests must not depend on live RAMS or output providers.
- Run `bin/rails test` and `bin/rubocop`; `bin/ci` also prepares databases, checks
  autoloading, and runs the generated Rails security/dependency checks.

## Authorization and external input

- The landing page and `/up` are public. No identity provider, user model, or reserve
  authorization policy is implemented. Do not expose operational data on public pages.
- Future authentication must not imply authorization. Scope reads and writes to the
  caller's permitted reserves, deny unauthorized access, and test cross-reserve boundaries.
  Do not assume RAMS permissions transfer automatically to FAIR Station.
- Keep CSRF protection, parameterized queries, strong parameters, and default HTML
  escaping. Validate redirects and filter credentials and sensitive metadata from logs.
- Keep application secrets in Rails encrypted credentials, not in source,
  fixtures, screenshots, logs, or a second deployment mechanism. The runtime
  deployment supplies only `RAILS_MASTER_KEY`; see the
  [README](../README.md#configuration-and-secrets).

## External-source provenance

- Preserve the source system, source identifier, retrieval time, and evidence needed
  to explain future imports or candidate matches. This is a provenance requirement,
  not a prescription for normalized tables or a research graph.
- Distinguish source assertions, inferred candidates, and human review decisions.
  Approval does not prove attendance; a funding record does not prove an award;
  an identifier does not prove an output came from a reserve.
- Preserve identifier types (DOI, ROR, ORCID, award identifiers), missing values,
  and source status semantics. Do not silently merge people, institutions, or outputs.
- When imports are designed, make repeat processing safe and preserve human review
  decisions. Define API failure behavior explicitly rather than turning errors into empty data.

## References

Adapted from [RAMS Rails guidelines](https://github.com/UCNRS-RAMS/ucnrs-rams/blob/main/docs/rails_guidelines.md).
FAIR Station uses Minitest and MySQL, not RAMS's RSpec/factory conventions;
RAMS-specific roles, existing presenters, and authentication choices are not inherited.
The concise [AGENTS.md](../AGENTS.md) follows the progressive-disclosure approach in
[Writing a Good AGENTS.md](https://www.philschmid.de/writing-good-agents).
