# Quail Ridge production sync validation — 2026-11-12

Evidence retrieved: `2026-11-13T01:26:18Z`. Source: `https://rams.ucnature.org/api/v1/`; reserve 27; source namespace `rams/ucnature`. This was a local FAIR Station development run. RAMS production was read-only. No merge or deployment occurred.

## Result

The full import and repeat run succeeded. All collection totals matched RAMS. Eight live detail responses (reverified at `2026-11-13T01:26:18Z`) matched their collection snapshots; all mapped fields in those samples matched local records. No sample shortfall.

| Resource | Pulled | RAMS total |
| --- | ---: | ---: |
| reserves | 1 | 1 |
| projects | 705 | 705 |
| team_memberships | 1516 | 1516 |
| visits | 2073 | 2073 |
| fundings | 177 | 177 |
| institutions | 121 | 121 |

| Local model | Before repeat | After repeat |
| --- | ---: | ---: |
| Station | 1 | 1 |
| ResearchActivity | 705 | 705 |
| Person | 950 | 950 |
| ActivityPerson | 1516 | 1516 |
| ActivityStation | 705 | 705 |
| SourceIdentifier | 3173 | 3173 |

## Model findings

- One RAMS thesis title is 293 characters; the original 255-character column rejected it. The import rolled back, the column was widened to text with a new migration, and the full run succeeded without truncation.
- 185 Quail Ridge visits reference projects outside the 705-project collection. RAMS authorizes visits by their own reserve. Their project stubs are retained only in the local evidence, and those projects were not fetched.
- 951 distinct RAMS user IDs resolved to 950 People because two source IDs shared an ORCID. 876 People have no ORCID; they remain identified by their typed RAMS user SourceIdentifier, never by name.
- All 705 projects have owner and applicant stubs. Their people and user SourceIdentifiers are imported, but the 705 owner relationships and 705 applicant relationships are not modeled. Team roles are imported only from team memberships.
- Visits (2,073), fundings (177), and institutions (121) have no domain model. No attendance, award, institution affiliation or ROR linkage is inferred from them.
- RAMS institution scope follows the API client. Historical membership institution references may name institutions absent from that endpoint because RAMS uses active memberships for that part of institution scoping.
- Existing station directory values remain curated. A campus ROR is not treated as a station ROR.

| Preserved station field | RAMS source | Local value |
| --- | --- | --- |
| short_name | `"Quail"` | `null` |
| description | `""` | `null` |
| doi | `"doi:10.21973/N30T0K"` | `"10.21973/N30T0K"` |
| latitude | `38.4827778` | `"38.482778"` |
| longitude | `122.14944444444446` | `"-122.149444"` |

The latitude difference is decimal rounding; longitude also differs in sign. RAMS prefixes the DOI with `doi:`. Blank/null directory values and the unfilled local short name remain explicit differences.

## Field-by-field project spot checks

Current: status=open and end_date absent or >= 2026-11-13. Historical: status=closed or end_date before 2026-11-13. Samples are newest current and oldest historical in RAMS creation order. “Current” is a source status/date classification, not evidence of attendance or approval.

| Source field | current 60944 | current 60808 | current 60774 | historical 51656 | historical 51655 | historical 51654 | historical 51653 | historical 51652 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| id | pass | pass | pass | pass | pass | pass | pass | pass |
| type | not stored | not stored | not stored | not stored | not stored | not stored | not stored | not stored |
| title | pass | pass | pass | pass | pass | pass | pass | pass |
| status | pass | pass | pass | pass | pass | pass | pass | pass |
| project_type | pass | pass | pass | pass | pass | pass | pass | pass |
| abstract | pass | pass | pass | pass | pass | pass | pass | pass |
| discipline | pass | pass | pass | pass | pass | pass | pass | pass |
| discipline_other | pass | pass | pass | pass | pass | pass | pass | pass |
| keywords | pass | pass | pass | pass | pass | pass | pass | pass |
| taxonomic_keywords | pass | pass | pass | pass | pass | pass | pass | pass |
| thesis_title | pass | pass | pass | pass | pass | pass | pass | pass |
| course_title | pass | pass | pass | pass | pass | pass | pass | pass |
| course_number | pass | pass | pass | pass | pass | pass | pass | pass |
| start_date | pass | pass | pass | pass | pass | pass | pass | pass |
| end_date | pass | pass | pass | pass | pass | pass | pass | pass |
| submitted_at | pass | pass | pass | pass | pass | pass | pass | pass |
| reserve | pass | pass | pass | pass | pass | pass | pass | pass |
| owner | pass | pass | pass | pass | pass | pass | pass | pass |
| owner.full_name | pass | pass | pass | pass | pass | pass | pass | pass |
| owner.orcid | pass | pass | pass | pass | pass | pass | pass | pass |
| applicant | pass | pass | pass | pass | pass | pass | pass | pass |
| applicant.full_name | pass | pass | pass | pass | pass | pass | pass | pass |
| applicant.orcid | pass | pass | pass | pass | pass | pass | pass | pass |
| created_at | not stored | not stored | not stored | not stored | not stored | not stored | not stored | not stored |
| updated_at | not stored | not stored | not stored | not stored | not stored | not stored | not stored | not stored |

`id` checks the typed SourceIdentifier; `reserve` checks ActivityStation. Owner/applicant passes mean person identity presence only; the relationships are dropped. `created_at`, `updated_at` and type envelopes are not copied into activity attributes. All 14 mapped activity fields were compared, including null values and normalized timestamp formatting. All 32 nested name/ORCID assertions also matched their local People (ORCIDs normalized by the Person model).

The complete source/stored values and API snapshot are local-only at `tmp/rams-sync/run-20261112-12224-qr6mqz/report.json`. This checked-in report omits person names and ORCIDs.

## Dropped-fields inventory

Every observed leaf path not imported into the domain graph is listed below, including type envelopes, nested IDs, source timestamps and unknown fields. Existing station fields are listed because the sync preserves local values rather than copying the source. Owner/applicant relationship loss is additional to these leaf paths and is described above. IDs belonging to unsupported resources have no target model, so no SourceIdentifier is created for them.

`present` counts occurrences (including nulls); `nonblank` counts nonblank assertions, including false booleans. Array paths use `[]`, so occurrences may exceed record counts. A bare array/object path represents an empty or null value. These assertions remain in the local evidence file, but are absent from the current application model.

### reserves

| Field path | Present | Nonblank |
| --- | ---: | ---: |
| `address_city` | 1 | 1 |
| `address_line_1` | 1 | 1 |
| `address_line_2` | 1 | 1 |
| `address_postal_code` | 1 | 1 |
| `country.code` | 1 | 1 |
| `country.id` | 1 | 1 |
| `country.name` | 1 | 1 |
| `country.type` | 1 | 1 |
| `created_at` | 1 | 0 |
| `description` | 1 | 0 |
| `doi` | 1 | 1 |
| `home_page_url` | 1 | 1 |
| `latitude` | 1 | 1 |
| `longitude` | 1 | 1 |
| `managing_campus.acronym` | 1 | 1 |
| `managing_campus.id` | 1 | 1 |
| `managing_campus.name` | 1 | 1 |
| `managing_campus.type` | 1 | 1 |
| `name` | 1 | 1 |
| `short_name` | 1 | 1 |
| `state.code` | 1 | 1 |
| `state.id` | 1 | 1 |
| `state.name` | 1 | 1 |
| `state.type` | 1 | 1 |
| `type` | 1 | 1 |
| `updated_at` | 1 | 1 |
| `year_reserve_established` | 1 | 1 |

### projects

| Field path | Present | Nonblank |
| --- | ---: | ---: |
| `applicant.type` | 705 | 705 |
| `created_at` | 705 | 705 |
| `owner.type` | 705 | 705 |
| `reserve.name` | 705 | 705 |
| `reserve.short_name` | 705 | 705 |
| `reserve.type` | 705 | 705 |
| `type` | 705 | 705 |
| `updated_at` | 705 | 689 |

### team_memberships

| Field path | Present | Nonblank |
| --- | ---: | ---: |
| `created_at` | 1516 | 793 |
| `institution.acronym` | 1516 | 1215 |
| `institution.id` | 1516 | 1516 |
| `institution.name` | 1516 | 1516 |
| `institution.type` | 1516 | 1516 |
| `project.project_type` | 1516 | 1516 |
| `project.title` | 1516 | 1516 |
| `project.type` | 1516 | 1516 |
| `type` | 1516 | 1516 |
| `updated_at` | 1516 | 817 |
| `user.type` | 1516 | 1516 |

### visits

| Field path | Present | Nonblank |
| --- | ---: | ---: |
| `created_at` | 2073 | 2073 |
| `end_date` | 2073 | 1906 |
| `ends_at` | 2073 | 2031 |
| `id` | 2073 | 2073 |
| `project.id` | 2073 | 2073 |
| `project.project_type` | 2073 | 2073 |
| `project.title` | 2073 | 2073 |
| `project.type` | 2073 | 2073 |
| `public_use_category` | 2073 | 2073 |
| `purpose_of_visit` | 2073 | 2066 |
| `reserve.id` | 2073 | 2073 |
| `reserve.name` | 2073 | 2073 |
| `reserve.short_name` | 2073 | 2073 |
| `reserve.type` | 2073 | 2073 |
| `start_date` | 2073 | 1906 |
| `starts_at` | 2073 | 2031 |
| `status` | 2073 | 2073 |
| `study_area` | 2073 | 138 |
| `submitted_at` | 2073 | 2018 |
| `submitter.full_name` | 2073 | 2073 |
| `submitter.id` | 2073 | 2073 |
| `submitter.orcid` | 2073 | 373 |
| `submitter.type` | 2073 | 2073 |
| `type` | 2073 | 2073 |
| `updated_at` | 2073 | 1247 |
| `visitors` | 54 | 0 |
| `visitors[].arrives_at` | 4772 | 4772 |
| `visitors[].count` | 4772 | 4772 |
| `visitors[].departs_at` | 4772 | 4772 |
| `visitors[].institution.acronym` | 4772 | 3893 |
| `visitors[].institution.id` | 4772 | 4772 |
| `visitors[].institution.name` | 4772 | 4772 |
| `visitors[].institution.type` | 4772 | 4772 |
| `visitors[].role` | 4772 | 4772 |
| `visitors[].user.full_name` | 4772 | 4772 |
| `visitors[].user.id` | 4772 | 4772 |
| `visitors[].user.orcid` | 4772 | 476 |
| `visitors[].user.type` | 4772 | 4772 |

### fundings

| Field path | Present | Nonblank |
| --- | ---: | ---: |
| `co_principal_investigators` | 177 | 19 |
| `created_at` | 177 | 34 |
| `end_date` | 177 | 177 |
| `funding_opportunity_number` | 177 | 0 |
| `grant_number` | 177 | 53 |
| `id` | 177 | 177 |
| `is_funded` | 177 | 177 |
| `is_submitted` | 177 | 177 |
| `principal_investigators` | 177 | 68 |
| `project.id` | 177 | 177 |
| `project.project_type` | 177 | 177 |
| `project.title` | 177 | 177 |
| `project.type` | 177 | 177 |
| `reserve.id` | 177 | 177 |
| `reserve.name` | 177 | 177 |
| `reserve.short_name` | 177 | 177 |
| `reserve.type` | 177 | 177 |
| `sponsor` | 177 | 0 |
| `sponsor_other` | 177 | 106 |
| `start_date` | 177 | 177 |
| `title` | 177 | 103 |
| `type` | 177 | 177 |
| `updated_at` | 177 | 34 |
| `was_denied` | 177 | 0 |
| `will_be_submitted` | 177 | 177 |

### institutions

| Field path | Present | Nonblank |
| --- | ---: | ---: |
| `acronym` | 121 | 19 |
| `city` | 121 | 121 |
| `country.code` | 121 | 121 |
| `country.id` | 121 | 121 |
| `country.name` | 121 | 121 |
| `country.type` | 121 | 121 |
| `created_at` | 121 | 121 |
| `id` | 121 | 121 |
| `institution_type` | 121 | 121 |
| `name` | 121 | 121 |
| `ror` | 32 | 0 |
| `ror.id` | 89 | 89 |
| `ror.name` | 89 | 89 |
| `ror.ror_id` | 89 | 89 |
| `ror.type` | 89 | 89 |
| `state` | 18 | 0 |
| `state.code` | 103 | 103 |
| `state.id` | 103 | 103 |
| `state.name` | 103 | 103 |
| `state.type` | 103 | 103 |
| `type` | 121 | 121 |
| `updated_at` | 121 | 121 |

## Verification

`bin/ci` passed with Ruby 4.0.6: 49 tests, 231 assertions; RuboCop, dependency audits, Brakeman and Zeitwerk all passed. Tests use synthetic data and HTTP-boundary doubles, never RAMS production. The live repeat run preserved counts for Station, ResearchActivity, Person, ActivityPerson, ActivityStation and SourceIdentifier.

## Review follow-up validation

The refactored task was re-run against production after moving settings and the
field crosswalk into `config/rams.yml`. Collection totals, dropped-field counts,
eight project checks and all 32 nested person comparisons were verified again.
All six local model counts remained unchanged. This full rerun issued eight
uncached SELECTs; source identities and ORCID matches are loaded in batches.

Regression coverage now includes consistent shared-membership role updates,
conflicting incoming memberships, contradictory ORCID assertions, snapshot/report
write failures, evidence file permissions, HTTP reads before the transaction,
and bounded SELECT counts as the number of projects grows. Persisted values are
re-read in batches for report comparisons. Source snapshots are staged before
import and the report is flushed and synced before commit, so evidence-write
failures prevent the database import from committing.
