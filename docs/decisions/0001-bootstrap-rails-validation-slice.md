# ADR 0001: Bootstrap Rails around one RAMS import slice

Status: accepted for validation

## Context

FAIR Station needs to test whether one source-owned research record can become
a connected, source-independent `ResearchActivity`. The user interface, RAMS
endpoint, production database, deployment environment, authentication scheme,
and public exchange contract are not yet established.

## Decision

Bootstrap a Rails 8.1 application using the locally verified Ruby 4.0 and
SQLite versions. Keep HTML rendering available, but expose JSON only for this
slice. Omit mail, storage, websockets, JavaScript, asset pipeline, and deployment
scaffolding until a validated workflow needs them.

The executable slice imports a RAMS `Research` project with team memberships,
people, time-specific affiliations, visits, visit attendance, and host stations.
Funding is not executable in this slice because its source representation and
precedence rules have not been validated.

FAIR Station initiates the pull. The first trigger is a Rails task rather than
an inbound import endpoint; no current workflow requires another system or UI
to command FAIR Station over HTTP.

Responsibilities are separated as follows:

- `HttpClient` owns reusable GET, JSON parsing, timeout, and HTTP failure
  mechanics without knowing which source it serves.
- `RamsAdapter` owns the RAMS endpoint, authentication header, payload fields,
  source IDs, and the provisional rule that only completed, non-future visits
  establish `first_visit_started_at`. It returns an unsaved graph composed of
  the ordinary FAIR Station Rails models.
- `SourceAdapters` is the composition point that selects an adapter by the
  registered source name; it contains no source mapping policy.
- `ImportResearchActivity` asks the adapter to pull the activity and owns the
  transaction and repeat-import behavior.
- Active Record models store the connected graph and enforce relational and
  source-identity invariants.
- A Rails task is the initial import trigger. The controller and serializer
  provide only the read interface for inspecting stored state.

The import updates the existing activity selected by `(source, source_id)` and
replaces its source-owned connected records in one transaction. Shared source
entities such as people and stations are upserted by their own source identity.

Do not introduce a base adapter yet. The operation currently relies only on the
adapter method it needs, and a second integration will determine whether a
shared protocol or implementation is warranted.

## Consequences

The first RAMS endpoint and JSON shape are explicit but provisional. The fixture
is a proposed contract for coordination with RAMS, not evidence that RAMS
currently serves it. Authentication is represented only as an optional bearer
token.

Replacing connected rows makes retry outcomes deterministic and removes stale
source relationships, but child FAIR Station IDs are not stable across an
update. Reconciliation, tombstones, detailed change history, partial imports,
funding, background execution, and production persistence remain open work.

SQLite is a bootstrap choice, not a commitment for production. A deployment or
concurrency workflow must validate the production persistence decision.

## Non-RAMS check

A structured form can supply the same connected input without adopting RAMS
names: a submission identifies a research activity, repeats people with their
roles and affiliations, and repeats station visits with attendance. Its
connector and mapper would remain at its own source boundary. A form that only
supplies one timeless institution or one station field would expose missing
relationships instead of causing FAIR Station to infer them.
