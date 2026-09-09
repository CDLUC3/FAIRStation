# FAIR Station — Rails Development Guidelines

Coding standards, testing conventions, and architectural rules for Rails development.

## Table of Contents

1. [Models & Domain Objects](#models--domain-objects)
2. [Controllers](#controllers)
3. [Testing](#testing)
4. [Database & Migrations](#database--migrations)
5. [Security](#security)
6. [Views & Presenters](#views--presenters)
7. [Code Comments](#code-comments)

---

## Models & Domain Objects

- **No service objects.** All domain classes live in `app/models/` with namespaces, never `app/services/`.
- **Name classes after domain nouns, not actions.** No `*Service`, `*Manager`, `*Handler` suffixes.
- Use `ActiveModel::Model` for POROs that need validation or form integration.
- Replace `.call` / `.perform` with domain verbs: `#save`, `#complete`, `#submit`, `#deliver`.
- Look to identify domain models that can be extracted when an existing model is large.
- **Callbacks only for data integrity** (normalise fields, set defaults). Never for emails, payments, or external systems.
- Prefer composition over inheritance. Extract behaviour into small, focused objects.
- Avoid feature envy, long parameter lists, case statements on type, and mixin abuse.
- Every imported record must carry `source` and `source_id` columns for idempotency and provenance.

## Controllers

- Controllers handle HTTP only: receive request, delegate to model, return response.
- Avoid long actions, since they often signal business logic that belongs in a model or PORO.
- **Maximum one instance variable per action.**
- No business logic, calculations, email sending, or multi-object operations in controllers.
- Return `status: :unprocessable_entity` on failed form renders (required by Turbo).
- Prefer RESTful routes. Custom verb actions (e.g., `post "activate"`) usually mean a missing noun/resource (e.g., `resource :trial, only: [:create]`).

## Testing

- **Must use TDD.** Write tests first and follow red, green, refactor.
- **Must not use `let` or `before` in specs** (avoid mystery guests). Do test setup within each test.
- Test behaviour, not implementation. Four Phase Test: setup, exercise, verify, teardown.
- **Test pyramid:** many model/PORO unit tests, some request tests, few system tests.
- Every public method on every model and PORO must have at least one test.
- Every branch in a conditional must have at least one test.
- Use `build` / `build_stubbed` over `create` unless persistence is needed.
- **Factories:** only required attributes with sensible defaults. Start in `test/factories.rb`.
- Use Shoulda Matchers for validations and associations.
- **WebMock blocks all external HTTP in tests** — always stub external requests.
- Never test private methods directly. Never stub the system under test.

## Database & Migrations

- Always use the `rails generate migration` command to create migration files.
- Use `text` over `string` if length varies significantly.
- Add `null: false` and database-level defaults where appropriate.
- Wrap multi-record operations in transactions. Use `save!` (bang) inside transactions.
- Keep scopes as one-liners. Complex queries belong in search/query objects.
- Never use `Post.all` without pagination.
- Avoid `.count` in loops. Use `counter_cache`.
- Use `uuid` primary keys for all tables. Add `source` (string) and `source_id` (string) to all import-facing tables with a unique index on `(source, source_id)`.

## Security

- Never interpolate user input into SQL. Use parameterised queries or `where(key: value)`.
- Always use strong parameters. Never `params.permit!`.
- Scope all queries to the current user or use Pundit authorisation.
- Every controller must have authentication unless explicitly public.
- Never use `raw`, `html_safe`, or `<%==` with user-supplied data.
- Never skip CSRF verification for browser-facing controllers.
- Filter sensitive params in logs: passwords, tokens, secrets, API keys.
- Never `render json: model` without explicit `only:` — whitelist attributes.
- Never redirect to `params[:return_to]` without validation.
- Use array form for system commands: `system("cmd", arg)`, never `system("cmd #{arg}")`.

## Views & Presenters

- Views render data. No calculations, queries, or complex conditionals.
- Use presenters to display logic. Instantiate in controller, use in view.
- Extract repeated markup into partials. Pass data via `locals:`, not instance variables.
- Helpers for simple formatting only (dates, currencies). If longer than 5 lines, use a presenter.
- Turbo: return `status: :unprocessable_entity` on failed forms. Keep Stimulus controllers small.

## Code Comments

- **Code comments are a smell, not a goal.** They should be rare. The code, its names, the tests, and the commit message carry the meaning. A comment is the last resort once none of those can.
- Before writing a comment, prefer these in loose order:
  1. **Rename** — a clearer method, variable, or class name that states the intent.
  2. **Extract** — pull a confusing expression into a well-named method that names the concept. If a whole concept is missing, extract the right PORO/domain class.
  3. **Test** — let a well-written spec tell the story of the behaviour and its edge cases.
  4. **Commit message** — explain the *why* and the history there, not in the source.
- Only then write a comment. Typically when the rationale matters but a commit message is too far removed from the code for someone to find it when they need it.
- Favour explaining *why* over *what* — the code already shows what it does, so restating it is noise. The rare exception is genuinely dense mechanics, e.g. a non-obvious algorithm, where naming what each step does earns its keep.
- No narration, no TODO/changelog/decision-log comments, no commented-out code.
