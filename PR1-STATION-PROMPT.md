Add the Station model and seed Quail Ridge Reserve, as PR 1 of the FAIR
Station output-discovery MVP.

First, reset the branch: this work goes on the existing branch
`feat/station-model` (PR #66). Check it out, then reset it to main
and discard everything currently on it — `git fetch origin`,
`git checkout feat/station-model`, `git reset --hard origin/main`.
Do not try to salvage or reuse anything from the previous version of
this branch. Start fresh from main. When you push, the existing PR #66
will update automatically — do not open a new PR.

Then build the model. Context to read first: FAIRStation issue #32
(schema), issue #30 (RAMS validation slice), and the RAMS API. The
repo itself is nearly empty — Rails 8, MySQL, no domain models yet —
so those issues are the context.

Non-negotiables:
- Station must be RAMS-agnostic. No `rams_*` column, or any source-specific
  column, on Station. Link back to source systems with a separate
  SourceIdentifier model (polymorphic, source_system + external_id as a
  string, unique so one external ID can't attach to two records).
- ROR and DOI can stay on Station — they're global identifiers, not
  source-specific.
- Seed only Quail Ridge, idempotently. Don't invent values you can't
  verify (ROR, DOI, coordinates, RAMS ID) — leave them null / uncreated.
- Nothing else in this PR: no sync, matching, UI, or auth.

Commit `feat: add Station model and Quail Ridge seed`. Run the migration,
add a model test, run RuboCop. Don't merge, don't open a PR yourself.
Report what you left blank and why.
