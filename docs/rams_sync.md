# Development RAMS import (draft)

Run `bin/rails 'rams:sync[ucnature,27]'` in development to select the UC Nature
connection and Quail Ridge reserve. The task refuses other Rails environments.
Store the token in Rails encrypted credentials at the path configured in
`config/sources.yml`.

The adapter retrieves all pages of reserves, memberships, visits, funding and
institutions. Visits and funding use the selected reserve filter. It then fetches
each distinct project referenced by those visits through the project detail API;
assigned reserve and reserve interest do not determine selection or attribution.
Other collections follow token visibility. Inaccessible or missing visit-linked
projects stop the run before writes; a token must be permitted to retrieve them.
A reserve without visits can complete an empty sync. It verifies scope and then
translates the collections before any database transaction. The importer saves
stations, people, activities and memberships atomically. Each membership retains
the institution ID and name asserted by RAMS, plus its ROR ID when available in
the retrieved institution directory. The affiliation describes that project
membership. A membership without an institution imports with empty affiliation
fields. Project owners and applicants import as separate `ActivityPerson` rows
with the RAMS roles `owner` and `applicant`, even without a team membership.
Both roles can point to the same person. The sync resolves each person by their
typed RAMS user ID and uses the project ID and role to track the relationship.
A project assignment and team membership share a link when their project,
person, and role match. If RAMS reassigns the project role, the original team
membership stays with its person. Visits and funding remain unmodeled.

After migrating, rerun the same sync to backfill these roles on existing projects.
Reruns refresh mapped fields and reassign roles when RAMS reports a different user.
Removals remain outside this slice. Rolling back the role uniqueness migration
requires that each project and person have at most one link. The rollback stops
before changing the indexes if multiple role links exist.
The imported-record summary counts distinct records processed by the current
batch, including existing records on reruns, rather than installation-wide
totals or only newly created records.

`Rams::Snapshot` is a collected set of API responses, not an atomic point-in-time
snapshot. Offset pagination cannot detect every equal-count source change.
Network errors and invalid/inconsistent pagination stop the pull. There are no
automatic retries or incremental watermarks.

Before database writes, `Imports::SourceArchive` saves the retrieved collections
and their source URL, identity namespace, selected reserve, and retrieval time
under ignored `tmp/source-imports/run-*`. Files are mode 0600 inside a mode-0700
run directory. Archive-write failures prevent import; database failures remove
that run's archive. A process crash may leave orphan files, so their presence
alone does not prove database commit. The transaction also persists an `ImportRun`
receipt with retrieval and successful-sync times, absolute evidence paths and
SHA-256 checksums. Each processed source identifier links to that receipt. Failed
imports roll back the receipt and preserve the previous successful-sync timestamp.
Receipts identify local evidence; they do not back it up or provide per-field history.
See `docs/source_imports.md` for the freshness query and provenance boundaries.

## Open review decisions

- Source IDs establish person identity. Conflicting ORCID assertions stop the
  import; reviewed linking of different source identities remains undecided.
- Test-data and summary retention still need clarification.
- Detailed comparison tooling is deferred. The import requires its source
  archive, but does not require a separate comparison report to commit.

Tests use synthetic collections. No production counts, record identifiers,
source snapshots, or run findings belong in repository documentation.
