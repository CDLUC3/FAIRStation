# FAIR Station — Agent Onboarding

**Purpose:** Connect research at field stations and marine labs with the people, places, data, and outputs that make up the research lifecycle.

## Tech Stack

- **Framework:** Ruby on Rails (API-first; no view layer planned for v1)
- **Database:** PostgreSQL with `jsonb` for flexible metadata, `uuid` primary keys
- **Testing:** Minitest (Rails default)
- **External APIs:** ORCID, ROR, Crossref, DataCite, OpenAlex (stubbed in tests)

## Project Structure

- `app/integrations/` — Source system adapters (e.g., RAMS importer). One directory per source.
- `app/operations/` — Domain operations: data transformation, enrichment, and attribution inference. Named after domain nouns, never `*Service`.
- `app/models/` — ActiveRecord domain models and POROs using `ActiveModel::Model`.
- `test/` — Mirrors `app/` structure. Unit tests for models/operations, integration tests for source adapters.

## Domain Model Conventions

- Names are chosen for the **research lifecycle**, not the source system.
- Every imported record carries `(source, source_id)` for idempotency and provenance.
- Relationship names are **nouns** (`membership`, `attendance`, `attribution`), not verbs.
- Polymorphic associations use `*-able` naming.

## How to Build, Test, and Verify

```bash
bin/rails test                        # Full test suite
bin/rails test test/path/to_test.rb   # Single file
bin/rails test test/path/to_test.rb:42  # Single test
bin/rails db:migrate                  # Run migrations
bin/rails db:seed                     # Seed with sample stations/organizations
bundle exec rubocop                   # Lint
bundle exec rubocop -A                # Auto-fix lint issues
bin/rails routes                      # View routes
```

## Rules

- **Write tests first.** TDD: red, green, refactor. Every public method on every model and PORO must have at least one test.
- **No service objects.** Domain classes live in `app/models/` or `app/operations/`, named after nouns, never `*Service`, `*Manager`, `*Handler`.
- **Controllers handle HTTP only.** No business logic, no multi-object operations. Max one instance variable per action.
- **No logic in views.** When views are added, use presenters. Helpers for simple formatting only.
- **Callbacks only for data integrity.** Never for emails, external APIs, or side effects.
- **Use `save!` inside transactions.** Wrap multi-record operations in transactions.
- **Never `Post.all` without pagination.** Never `.count` in loops. Use `counter_cache`.
- **Scope all queries to the current user** or use Pundit authorization.
- **Never `render json: model` without explicit `only:`** — whitelist attributes.
- **Never interpolate user input into SQL.** Use parameterized queries or `where(key: value)`.
- **Always use strong parameters.** Never `params.permit!`.
- **Never use `raw`, `html_safe`, or `<%==`** with user-supplied data.
- **Never redirect to `params[:return_to]`** without validation.
- **Stub all external HTTP in tests.** Use WebMock.
- **Code comments are a last resort.** Rename, extract, or test instead. Explain *why*, never *what*.
- **No `let` or `before` in tests.** Do test setup within each test (avoid mystery guests).
- **Use `build` / `build_stubbed` over `create`** unless persistence is needed.
- **Factories:** only required attributes with sensible defaults. Start in `test/factories.rb`.
- **Every branch in a conditional must have at least one test.**
- **Return `status: :unprocessable_entity`** on failed form renders (required by Turbo).
- **Prefer RESTful routes.** Custom verb actions usually mean a missing noun/resource.
