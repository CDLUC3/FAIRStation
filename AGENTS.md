## Scope and current state

This file applies to the FAIR Station repository.

FAIR Station is an independent research-infrastructure service. It accepts
research context from multiple station workflows and connects that context into
a shared research model. RAMS is the first reference integration, not FAIR
Station's internal architecture and not the definition of its domain.

This repository currently contains planning and domain-contract documentation;
it does not yet establish an application framework, persistence technology, or
repository-wide coding conventions. Do not infer those choices from RAMS or
from examples in strategy documents. When implementation is added, update this
file with verified setup, test, formatting, and architectural conventions.

The current domain contract is
`docs/fair_station_research_record_contract.md`. Treat it as a working
hypothesis to test, not as a complete standard or an accidental database
design.

## Working principles

For every non-trivial change, ask:

> What must be true about the architecture for us to solve this problem sustainably?

Keep these principles in view:

- RAMS modernization is not the objective. RAMS maintainability is a constraint
  on achieving the objective.
- When software boundaries correspond to meaningful domain boundaries, both the
  implementation and the user's mental model become easier to understand.
- The moment a concept must be serialized, we discover whether the source or
  FAIR Station actually knows what that concept means.
- Learn through small, end-to-end validation slices. Do not turn provisional
  product assumptions into permanent architecture.
- Preserve source identity and provenance before attempting reconciliation or
  enrichment.
- Prefer explicit domain language and dependencies over generic abstractions.

## Product and system boundary

### FAIR Station owns

FAIR Station owns concepts and capabilities that must remain meaningful when
the source is not RAMS, including:

- the common research-activity model and relationships;
- FAIR Station identity for imported research activities;
- source registration, import state, provenance, and change history;
- adapters that translate source representations into the common model;
- cross-source reconciliation and enrichment when a validated workflow requires
  them;
- research-output discovery, evidence, matching, and confirmation;
- research-graph relationships and cross-source reporting; and
- public FAIR Station interfaces and their versioning.

### Source systems own

RAMS and other source systems own the operational facts and workflows used to
run their stations. In RAMS, these may include projects, visits, reservations,
approvals, facilities, lodging, permits, waivers, invoicing, and source-record
corrections.

FAIR Station must not become a second implementation of a source system's
operational workflow. Correct source facts at the source. FAIR Station may
preserve, map, and interpret them without silently asserting authority over
them.

### The integration contract

A source exposes or submits a documented representation of its own concepts.
Its FAIR Station adapter translates that representation into the common model
while retaining source identity and provenance.

The boundary is intentionally asymmetric:

1. a source describes its own record;
2. a source-specific adapter reads that representation;
3. an explicit mapper produces FAIR Station domain input; and
4. FAIR Station validates and records the resulting research activity.

Do not couple FAIR Station persistence to RAMS tables, Rails models, URLs, or UI
structure. Do not require RAMS to adopt FAIR Station's internal model.

## Decide where behavior belongs

Before implementing work that crosses a system boundary, answer:

1. Must the concept or behavior work for a non-RAMS source? If yes, it probably
   belongs in FAIR Station.
2. Would a station still need the behavior if FAIR Station were unavailable?
   If yes, it probably belongs in the source system.
3. Is the work faithfully representing a source record, or is it mapping,
   normalization, reconciliation, enrichment, or inference? Representation
   belongs at the source boundary; the latter responsibilities belong in FAIR
   Station.
4. Which system is authoritative for correcting the underlying fact?
5. Does the proposed FAIR Station concept only make sense because RAMS has a
   similarly named table or model? If so, test it against another workflow.
6. Is an inferred relationship being presented as a source assertion? If so,
   preserve the distinction and its evidence.

Some workflows intentionally cross the boundary. For example, RAMS may collect
ORCID, ROR, or consent during a project workflow, while FAIR Station validates,
normalizes, or uses that information later. Make ownership explicit on both
sides instead of hiding the split in a generic integration service.

## Domain-model discipline

### Current version 1 vocabulary

The central concept is `ResearchActivity`: a coherent research endeavor hosted
or supported by a station.

The current supporting concepts are:

- `Station`: the field station, reserve, or comparable host;
- `Person`: someone participating in the research;
- `Participation`: the relationship between a person and a research activity,
  including role and affiliation at that time; and
- `Organization`: an institution associated with a participation.

Relationships are first-class parts of the model. Do not import disconnected
people, organizations, stations, and activities and expect later code to guess
how they relate. In particular, do not flatten `Participation` into a timeless
person-to-organization attribute.

### Keep three schemas distinct

Do not use the word "schema" ambiguously. Distinguish:

1. the common domain model: concepts and relationships independent of a source;
2. the persistence schema: tables, indexes, and storage representation; and
3. an exchange schema: JSON or another public payload contract.

The latter two should serve the common model, but they need not mirror it
one-for-one. A database migration or serializer is not, by itself, a domain
decision.

### Source identity and public identifiers

Every imported `ResearchActivity` must retain:

- `source`: the originating system, not its technology; and
- `source_id`: an opaque, stable identifier chosen by that source.

Treat `(source, source_id)` as the identity of an imported source activity for
idempotency. A FAIR Station internal identifier serves a separate purpose.

ORCID and ROR are public identifiers, not source references. Do not use them as
substitutes for provenance. Do not assume that their presence proves two source
records represent the same entity; reconciliation is a separate operation with
its own evidence and policy.

### Evolve the model deliberately

When adding or changing a common concept:

1. state the user or system need;
2. give the concept a definition in domain language;
3. identify its relationships and invariants;
4. show how RAMS maps to it;
5. test it conceptually against at least one non-RAMS workflow;
6. define source identity and provenance behavior;
7. distinguish missing, unknown, inapplicable, deleted, and changed data; and
8. update the domain contract before or with implementation.

Do not generalize from one RAMS field merely because it is available. Do not
add a generic metadata hash to postpone naming a concept that the current slice
actually needs. Conversely, do not model speculative future detail without a
workflow that exercises it.

## Version 1 validation slice

The current slice should do only enough to validate the boundary and model:

1. read one RAMS project and its connected station and team information;
2. map it into the common FAIR Station model;
3. store or display the connected `ResearchActivity`; and
4. retain enough source identity to repeat, update, or diagnose the import.

Use this slice to learn whether the concepts and relationships are correct. A
working import that merely reproduces RAMS tables is not successful validation.

Unless the current task explicitly expands the contract, version 1 defers:

- a complete JSON Schema or public API;
- a final database schema;
- cross-source reconciliation and merging;
- visits, funding, permits, outputs, and activity logs;
- controlled vocabularies for types, roles, or statuses;
- ORCID, ROR, or other enrichment; and
- decisions about minting persistent identifiers.

When a deferred idea becomes necessary, revise the contract and explain what
newly validated workflow requires it.

## Change strategy

### Build the smallest coherent vertical slice

Prefer a thin path through a real boundary over a broad horizontal framework.
A slice should make its input, mapping, domain behavior, persistence or display,
and observable result clear.

Do not build a universal ingestion platform before the first RAMS import works.
Do not optimize only for the smallest diff if that hides a responsibility. Make
the smallest coherent change: enough structure to keep the boundary visible,
without speculative infrastructure.

### Keep source-specific knowledge at the edge

RAMS-specific field names, authentication, pagination, status values, and error
shapes belong in a RAMS adapter or client boundary. Translate them before they
reach the common domain.

Do not pass raw provider hashes through the application. Use explicit input
objects or typed structures where they clarify the contract. Preserve the raw
source identifier and enough diagnostic context to trace failures without
storing secrets.

Imports and updates must be deliberately idempotent. Make retry behavior,
transaction boundaries, partial failure, and duplicate handling explicit.

### Do not invent repository conventions

Until an implementation stack is committed:

- do not add Rails, a database, a queue, or an API framework solely because the
  first source is a Rails application;
- do not record commands or directory conventions that cannot be run here;
- do not introduce a large framework scaffold to encode the whole product
  strategy; and
- document consequential technology choices in an ADR or equivalent decision
  record.

Once conventions exist, inspect neighboring code and tests before adding a new
pattern. Prefer one established approach over parallel ways to perform the same
work.

## Layered application guidance

Use the separation-of-responsibilities ideas in Ryan Bigg's *Maintainable
Rails* when implementation begins. These are design constraints, not a mandate
to adopt ROM, dry-rb, or any specific gem.

If Rails is selected, keep Rails conventions where they clarify the
application, and add a layer only when it makes a real responsibility or
dependency visible.

### Delivery layer

Controllers, jobs, tasks, and command handlers translate an external trigger
into one application action and translate its result back. They may handle
authentication, authorization, input parsing, and response formatting.

Keep multi-step import workflows, network calls, mapping policy, and coordinated
writes out of controllers and jobs.

### Application operations

Give a significant user or system action one explicit entry point. Name it in
FAIR Station domain language, such as importing or updating a research
activity, rather than as a generic `SomethingService`.

An operation coordinates validation, domain behavior, persistence, and external
boundaries. Its steps, success value, and failure outcomes should be visible.
Do not disguise a collection of unrelated side effects behind `.call`.

### Domain layer

Domain objects express FAIR Station concepts, relationships, and invariants.
They should be testable without hidden database or network access.

Do not place source-specific payload fields, HTTP behavior, persistence queries,
or serialization policy in the common domain. Do not let persistence models
become the only definition of domain meaning.

### Persistence layer

Make database access visible. Introduce query or repository boundaries when
they clarify substantial reads, graph-shaped data, import identity, or
coordinated persistence. Do not wrap simple persistence mechanically merely to
use architectural terminology.

Prefer explicit workflows over important behavior hidden in callbacks.

### External adapters

Keep source and provider behavior in small adapters or clients. An adapter may
authenticate, fetch, parse, and translate provider failures. Mapping from a
source representation into the common model must be explicit and testable.

Do not design a lowest-common-denominator base adapter before a second source
demonstrates what is genuinely shared. Extract shared protocols from working
integrations rather than inheritance guesses.

### Serialization

A serializer is a public or internal contract, not a dump of a persistence
record. Choose fields and relationships deliberately, distinguish identifiers
from labels, define null and change behavior, and avoid leaking join tables or
framework structure.

## Testing

Tests should protect responsibilities and make the model easier to revise.

As implementation appears, prefer:

- plain unit tests for domain definitions and invariants;
- fixture-based adapter tests for source representations and provider errors;
- mapping tests that show the complete connected result;
- operation tests for orchestration, idempotency, and failure paths;
- persistence integration tests for source-identity uniqueness and updates;
- contract-focused tests for public interfaces; and
- a small number of end-to-end tests for validated workflows.

The first integration must include a representative RAMS example and a
documented non-RAMS scenario. The non-RAMS scenario may initially be a model
example rather than executable code, but it must be specific enough to reveal
RAMS-only assumptions.

Do not require a database, network request, or full application boot for logic
that does not need one. For a bug, add the narrowest regression test at the
failed responsibility and a boundary-level test when the failure crossed
systems.

Verified repository commands:

- `bin/setup --skip-server` prepares dependencies and databases;
- `bin/rails test` runs the test suite;
- `bin/rubocop` checks Ruby formatting;
- `bin/brakeman --no-pager` performs static security analysis; and
- `bin/rails zeitwerk:check` verifies autoloading conventions.

The application currently uses Rails 8.1, Ruby 4.0, and SQLite for the
validation slice. Treat SQLite as a bootstrap choice rather than a verified
production persistence decision.

## Documentation and decisions

Keep different kinds of decisions in the right place:

- update `docs/fair_station_research_record_contract.md` for changes to common
  concepts, definitions, relationships, source identity, or version scope;
- use ADRs or equivalent decision records for consequential technology,
  persistence, integration, identity, and public-contract choices;
- keep repository-specific workflow and coding instructions in this file; and
- keep product possibilities in strategy documents until a validated slice
  brings them into scope.

Label statements as current facts, working hypotheses, or future possibilities.
Do not silently promote a strategy-document possibility into a requirement.

## Agent workflow

Before a non-trivial change:

1. Read this file and the relevant domain contract, code, tests, and decisions.
2. State the user or system behavior being changed.
3. Identify the owning system and every boundary crossed.
4. Classify the work as source adapter, mapping, common domain, application
   operation, persistence, or delivery/interface behavior.
5. Name the validation question and separate verified facts from proposals.
6. Implement the smallest coherent vertical slice.
7. Run the narrowest relevant tests first, then the broader affected suite.
8. Update the domain contract or decision record when meaning or architecture
   changes.
9. Report behavior changed, tests run, architectural tradeoffs, and unresolved
   domain questions.

For source-to-FAIR Station work, final review must answer:

- Does the FAIR Station concept still make sense for a non-RAMS source?
- Is source-specific knowledge confined to the adapter boundary?
- Are relationships supplied explicitly rather than reconstructed by guesswork?
- Are source identity, provenance, assertions, and inferences distinguishable?
- Is there one explicit authority for correcting each underlying fact?
- Are network calls, persistence, retries, and other side effects visible?
- Is the operation safe to repeat?
- Did the change implement only what the current validation slice needs?

Prefer boring, explicit code with clear responsibilities. When uncertain, ask:

> If RAMS were replaced tomorrow by another station system or a structured form,
> would this FAIR Station concept and operation still make sense?
