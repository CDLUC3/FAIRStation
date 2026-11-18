# Development RAMS import (draft)

Run `bin/rails 'rams:sync[ucnature,27]'` in development to select the UC Nature
connection and Quail Ridge reserve. The task refuses other Rails environments.
Store the token in Rails encrypted credentials at the path configured in
`config/sources.yml`.

The adapter retrieves all pages of reserves, projects, memberships, visits,
funding and institutions. Projects, visits and funding use the selected reserve
filter; other collections follow token visibility. It verifies scope and then
translates the collections before any database transaction. The importer saves
stations, people, activities and memberships atomically; visits, institutions,
funding and owner/applicant relationships remain unmodeled. Reruns refresh mapped
fields without duplicating source identities. Removals remain outside this slice.
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
alone does not prove database commit. This is local provenance/debugging support,
not yet a persisted, per-record provenance history.

## Open review decisions

- RAMS permits reserve-independent projects and cross-reserve visits. The current
  selected-project query uses the optional project reserve; inclusion through
  visits and activity/station attribution need agreement before use.
- Source IDs establish person identity. Conflicting ORCID assertions stop the
  import; reviewed linking of different source identities remains undecided.
- Whether this development task should be retained needs Danny's clarification.
- Detailed comparison tooling is deferred. The import requires its source
  archive, but does not require a separate comparison report to commit.

Tests use synthetic collections. No production counts, record identifiers,
source snapshots, or run findings belong in repository documentation.
