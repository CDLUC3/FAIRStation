# FAIR Station schema: version 1

Status: working hypothesis for [ngRAMS issue #177](https://github.com/CDLUC3/ngRAMS/issues/177)

## What we mean by schema

The FAIR Station schema is primarily its **common domain model**: the concepts
FAIR Station needs and the relationships between them, independent of any one
source platform.

This is distinct from two implementation details that can come later:

- the database schema used to persist the model; and
- a JSON Schema used to validate data exchanged with FAIR Station.

Those implementations should follow the common model, but they do not need to
be designed before we can test the model. Version 1 is a small, revisable
hypothesis rather than a complete standard.

## The version 1 model

The central concept is a `ResearchActivity`: a coherent research endeavor
hosted or supported by a station.

```text
ResearchActivity
├── title
├── description (optional)
├── source record created at
├── station associations[] → Station
├── activity participations[] → Person
│                                ├── role
│                                └── affiliation → Organization (optional)
├── visits[] → Visit → hosted at → Station
│                      ├── starts at / ends at
│                      └── visit participations[] → activity participation
└── funding[] → Funding
```

The initial domain concepts are:

- **ResearchActivity** — the research being conducted.
- **Station** — the field station, reserve, or comparable host.
- **Person** — someone participating in the research.
- **Participation** — the relationship connecting a person to an activity,
  including their role and affiliation at that time.
- **Organization** — an institution associated with a participation.
- **ActivityStationAssociation** — an explicit relationship between a
  research activity and a station, independent of any particular visit.
- **Visit** — a bounded period during which some or all of an activity's
  participants are expected at one station.
- **VisitParticipation** — the relationship identifying which activity
  participants are associated with a particular visit. It may include that
  person's arrival and departure when the source supplies them.
- **Funding** — a source-described funding application, award, contract, or
  other financial support associated with an activity.

The relationships are part of the model. FAIR Station should not receive
disconnected people, stations, and activities and then guess how they relate.

An activity has zero or more source-asserted station associations independently
of its visits. Each association identifies one station; it is not evidence that
a visit occurred there. An activity can also have zero or more visits, and its
participants do not need to attend any visit. This supports people who
contribute through laboratory, analysis, administrative, or other off-station
work. A visit has exactly one host station in version 1; an activity can
therefore reach multiple stations through multiple visits, including stations
outside its direct station associations. A person must be an activity
participant before a `VisitParticipation` can connect them to one of its
visits.

The common relationship is provisionally named `ActivityStationAssociation`,
rather than `home`, `primary`, or `hosted at`. It is plural because the common
model must support research spanning multiple stations. RAMS currently exposes
at most one direct `Project#reserve` association, while the project's visits
can reference multiple reserves. The source model alone does not establish a
stronger meaning for the direct relationship. The first mapping must preserve
it separately from visit-to-reserve assertions and test its meaning with users
and a non-RAMS workflow.

### Dates and lifecycle milestones

Project-level dates must not be used as a substitute for visit dates. Version
1 retains two distinct milestones:

- `source_record_created_at` is when the source says its activity record was
  created. It is source lifecycle/provenance data, not the date the research
  began. It can support prompting people to develop a new record.
- `first_visit_started_at` is a derived activity milestone: the earliest start
  among visits that satisfy the import's documented occurred-visit rule. Its
  value must retain the visit and source facts from which it was derived. It
  can identify activities that progressed into station-use workflows such as
  permits and waivers.

Whether a scheduled visit counts as having "occurred" is not yet settled.
RAMS has visit dates and statuses, but a start date alone may not prove
attendance. The first slice must state its qualifying-status rule and must not
silently treat cancelled, denied, incomplete, or future visits as occurred.
Until that rule is validated, `first_visit_started_at` may be unknown even when
scheduled visits exist.

Research-level proposed start and end dates may still be useful, but their
meaning across sources is not established in version 1. They are not used to
infer visit timing.

### Funding in version 1

Funding is included because a real RAMS mapping can test and demonstrate a
useful research-reporting result. One activity can have zero or more funding
records. The initial shape carries only source-supported facts needed for that
mapping: title, sponsor as supplied, award or opportunity identifier when
present, funding period, amount when present, and source-described state.

The source remains authoritative for correcting these facts. FAIR Station does
not infer that a sponsor label is a reconciled `Organization`, that a submitted
application is an award, or that a missing amount means zero. RAMS represents
planned, submitted, funded, and denied states with multiple fields; the RAMS
mapper must define their precedence and report contradictory combinations
rather than concealing them. Sponsor reconciliation, currency normalization,
and a cross-source controlled funding-status vocabulary remain deferred.

## How source data becomes FAIR Station data

Each source has an adapter that translates its own concepts into the common
model:

```text
RAMS Project ─────── RAMS adapter ───────┐
                                         │
Another source ───── its adapter ────────┼──> FAIR Station model
                                         │
Structured form ──── its adapter ────────┘
```

For the reference implementation, the initial mapping is:

| RAMS concept | FAIR Station concept |
| --- | --- |
| Project | ResearchActivity |
| Project `created_at` | `source_record_created_at` |
| Project reserve | One item in the activity's station associations |
| Visit | Visit |
| Visit reserve | Visit's host Station |
| User | Person |
| Project team membership | Participation |
| User visit | VisitParticipation |
| Institution | Organization |
| Funding | Funding |

RAMS has research, class, meeting, public-use, and housing projects. The first
slice imports only RAMS projects whose source type is `Research`. That is an
adapter selection rule, not a claim that classes, retreats, meetings, or other
station uses are research activities. Those records remain important possible
inputs for operational and cross-station reporting, but admitting them requires
a separately validated common concept or an explicit expansion of
`ResearchActivity`.

RAMS's `first_reserve_visit_on_project?` behavior answers whether another visit
exists for the same project and reserve. It is not a project-wide first-visit
date and does not prove that attendance occurred. FAIR Station therefore
derives its milestone from imported visit facts under the documented occurred-
visit rule instead of mapping that RAMS predicate directly.

This mapping tests the common model; it does not make RAMS's structure the
common model. A source without projects, user accounts, or Active Record models
can map its own concepts into the same FAIR Station concepts.

## Source identity and provenance

Every imported `ResearchActivity` must retain a reference to the record that
produced it:

```json
{
  "source": "rams",
  "source_id": "projects/123"
}
```

`source` identifies the originating system, not its technology. `source_id` is
an opaque, stable identifier chosen by that source. For example, another source
might use a submission UUID or an API URL.

Together, `source` and `source_id` identify one imported activity:

```text
(rams, projects/123)             != (another-system, projects/123)
(rams, projects/123)             != (rams, projects/456)
```

FAIR Station can enforce uniqueness on that pair to prevent the same source
record from being imported twice. It may also assign its own internal ID to the
resulting `ResearchActivity`; that ID serves a different purpose.

Related people, stations, and organizations may carry their own source
references when the source gives them stable identities. They are not required
to have one in version 1. A form submission, for example, may identify the
activity but provide only a person's name and affiliation.

ORCID and ROR are public identifiers, not source references. They may help FAIR
Station recognize people and organizations, but reconciliation is not part of
the first workflow.

Visits and funding records also retain their source identifiers when available.
`VisitParticipation` retains the identity or source linkage needed to diagnose
which source attendance record produced it. Derived milestones cite those
source-linked records rather than presenting the derivation as a source
assertion. An omitted relationship means the source did not supply it; it must
not be interpreted as a confirmed statement that the relationship does not
exist.

## Adapter configuration hypothesis

Survey123, Qualtrics, and Google Forms may eventually support reusable
platform-level connectors, while each station supplies mapping configuration
for its particular questions and answer choices. The connector would own
platform behavior such as authentication, pagination, and response formats;
the station-specific mapping would state how that form represents visits,
people, stations, and funding.

This is a future possibility, not a version 1 ingestion framework. The RAMS
adapter remains explicit, and shared connector or configuration protocols
should be extracted only after a second working source reveals what is truly
common. Configuration must not turn unlabeled answers into generic metadata or
hide the meaning and provenance of a station's assertions.

## What version 1 will test

The first end-to-end slice will:

1. select one RAMS project of source type `Research` and read its creation
   timestamp, direct station association, team, visits, visit participants,
   visit reserves, and funding;
2. map it into the common model;
3. store or display the resulting connected research activity; and
4. show the source-record creation milestone, the explicitly derived first-
   visit milestone when supported, and mapped funding; and
5. retain enough source identity and derivation evidence to repeat, update, or
   diagnose the import.

We will then describe at least three non-RAMS workflows using the same model.
If they do not fit naturally, we will revise the model before treating it as a
stable contract.

## Deferred

Version 1 does not yet define:

- a complete JSON Schema or public API;
- the FAIR Station database tables;
- multiple-source reconciliation and merging;
- detailed visit operations such as reservations, amenities, permits, waivers,
  invoicing, or visit approval workflows;
- funding sponsor reconciliation, currency normalization, or a controlled
  cross-source status vocabulary;
- non-research station activities such as classes, meetings, retreats, public
  use, or housing;
- controlled vocabularies for activity types, roles, or statuses; or
- enrichment through ORCID, ROR, or other services.

These should be added when a tested workflow requires them.
