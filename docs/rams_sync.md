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
- Person association by supplied ORCID is a separate draft identity policy.
- Whether this development task should be retained needs Danny's clarification.
- Detailed diagnostics are a separate draft layer. This import does not require
  a full comparison report to commit; it does require its source archive.

Tests use synthetic collections. No production counts, record identifiers,
source snapshots, or run findings belong in repository documentation.

## Optional read-only diagnostics

After an import, run `bin/rails 'rams:validate[ucnature,27]'` to retrieve fresh
source data and compare samples with the existing local database. This command
performs no domain writes. It archives that retrieval and a restricted local
JSON report; report failures remove only that diagnostic run's incomplete files.
They cannot roll back an earlier import or prevent a normal `rams:sync` run.

The report includes counts, station differences preserved, unmapped nested JSON
field paths, excluded memberships, unmodeled relationships, and visits whose
projects are outside the selected project collection. A leaf is a final nested
value such as `institution.name`. An unmapped field is not invalid source data.
Three current and five historical projects are sampled where available; missing
samples are counted. Sample detail responses are rechecked against the collection.
Field comparisons show incoming and stored values, accounting for normalization.
Nested person discrepancies are reported; top-level mapped project mismatches
stop the diagnostic run. These are spot checks using the same mapping as the
adapter, not independent proof that every mapping or imported record is correct.

Here, evidence means source assertions, retrieval metadata, and import diagnostic
material. It does not prove attendance or a relationship to a research output.
The report references its source archive rather than duplicating the full input.
Keep reports and production findings outside version control. The precise
retention policy and future persisted provenance model remain review decisions.
