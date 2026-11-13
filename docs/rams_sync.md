# Quail Ridge RAMS sync

`bin/rails rams:sync_quail_ridge` is a manual, full production API pull into
FAIR Station **development**. It refuses to run in other Rails environments.
It neither writes to RAMS nor starts a background job. No merge or deployment
is part of this test run.

## Credentials and execution

The token must be an active RAMS ApiClient scoped only to Quail Ridge, reserve
27. The task checks the visible reserve directory before fetching research.
Store the application token in Rails encrypted credentials as `rams.api_token`.
The explicit exception for this development test run is a process-local
`RAMS_API_TOKEN`, which takes precedence over credentials. Do not add that
variable to deployment configuration or put a token in source or shell history.
The original key for this run is in Proton Pass, RAMS vault, item
“Quail Ridge RAMS Key”. The integration has no dependency on the vault CLI.

Activate `.ruby-version`, prepare the local database, and run:

```sh
bin/rails db:prepare
bin/rails rams:sync_quail_ridge
```

The production base URL is fixed to `https://rams.ucnature.org/api/v1/`.
There is no environment fallback. An empty project collection stops the run.
All collection requests use `per_page=100` and follow RAMS pagination metadata.
No endpoint receives `updated_since`. Retrieval order is reserves, projects,
team memberships, visits, fundings, institutions. Memberships and institutions
have no reserve filter; their scope comes from the restricted API client.

Redirects, HTTP errors (including 401/429), network failures, duplicate IDs,
inconsistent counts, and scope violations stop the run. There are no automatic
retries. Rerun the full task after resolving the error or rate limit. The client
reports status and Retry-After without printing the token or response body.
Offset pagination cannot provide snapshot isolation; count changes and changed
spot-check records are detected, but equal-count changes elsewhere may escape.

## Import behavior

The importer fetches and checks all collections before writing. Station,
research activity, person and membership writes share one transaction. Validation
failure rolls them back. The validation detail requests also happen within this
transaction; network timeouts are bounded. After commit, the task writes a
mode-0600 JSON report and source snapshot under ignored `tmp/rams-sync/`.
If writing the file fails, the database import has already committed; rerunning
is safe. The snapshot contains operational research/person data; keep it local.

Source identities use `source_system=rams`, `source_instance=ucnature`, and
`record_type` in every lookup. Reserve IDs identify Stations, project IDs identify
ResearchActivities, user IDs identify People, and team membership IDs identify
ActivityPeople. The activity-station relation is an ActivityStation. No RAMS
column is added to any domain model. IDs in unsupported records are listed as
dropped fields; there is no target record for a SourceIdentifier.

People match normalized ORCID first when available, otherwise an existing RAMS
user SourceIdentifier. Names are never an identity key; ORCID can be null.
Contradictory source/ORCID identities stop the import rather than merging records.
Roles, active flags and PI assertions come only from team memberships. Owner and
applicant stubs create or identify People but their relationships are not modeled.
Multiple user IDs sharing an ORCID may share one Person. Multiple membership IDs
may identify one ActivityPerson only when their role/active/PI values agree.
Conflicting memberships stop the run.

Existing station values are curated and preserved, including Quail Ridge's
corrected negative longitude, DOI and station-specific ROR decision. The source
reserve payload and differences appear in the report. A missing station is
initialized from RAMS directory fields; the task does not infer a station ROR
from its managing institution. Imported activity/person/membership fields are
refreshed from RAMS on reruns; absent records are not deleted. Diffing, deletion
reconciliation and human-review conflict resolution are outside this slice.
Source timestamps are not copied over local persistence timestamps; retrieval
time and full source assertions are retained in the local report.

Visits are scoped by their own reserve, not their project's reserve. A Quail
Ridge visit may legitimately reference a project absent from the Quail Ridge
project collection. Those references are reported and do not trigger broader
project pulls. Visits, fundings and institutions have no model in this slice:
all are fetched and every observed leaf field is inventoried as not imported.
New, unknown fields are inventoried automatically, including nested identifiers.

## Validation

The report records pulled/API totals for every collection, imported record counts,
station differences, dropped-field occurrence/nonblank counts, and field-level
comparisons for three current and five historical projects where available.
Current means RAMS `status=open` with no end date or an end date on/after the
run date. Historical means closed or an end date before the run date. Samples use the API's creation order: newest current and oldest
historical projects. Sample shortfalls are explicit. Each sampled project is
re-fetched from its detail endpoint and compared with the collection snapshot;
all mapped fields, source IDs, station links, and owner/applicant person presence
are checked against local records. Nested person names and normalized ORCIDs
are compared individually; differences are explicit in the JSON rather than
hiding source name variants behind a canonical Person name. Unmapped fields are labeled as such, not
counted as successful storage comparisons. The detailed JSON includes source
and stored values, while the checked-in run report summarizes findings without
copying person names or ORCIDs.

A production thesis title exceeded 255 characters during validation. The added
migration widens `research_activities.thesis_title` to text. Its rollback is
explicitly irreversible because narrowing would risk truncation; restoring the
old type needs a separate data review.
