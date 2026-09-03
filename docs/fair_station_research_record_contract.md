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
├── activity type (optional)
├── dates (optional)
├── hosted at → Station
└── participation → Person
                    ├── role
                    └── affiliation → Organization (optional)
```

The initial domain concepts are:

- **ResearchActivity** — the research being conducted.
- **Station** — the field station, reserve, or comparable host.
- **Person** — someone participating in the research.
- **Participation** — the relationship connecting a person to an activity,
  including their role and affiliation at that time.
- **Organization** — an institution associated with a participation.

The relationships are part of the model. FAIR Station should not receive
disconnected people, stations, and activities and then guess how they relate.

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
| Reserve | Station |
| User | Person |
| Project team membership | Participation |
| Institution | Organization |

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

## What version 1 will test

The first end-to-end slice will:

1. read one RAMS project and its connected station and team information;
2. map it into the common model;
3. store or display the resulting connected research activity; and
4. retain enough source identity to repeat or diagnose the import.

We will then describe at least three non-RAMS workflows using the same model.
If they do not fit naturally, we will revise the model before treating it as a
stable contract.

## Deferred

Version 1 does not yet define:

- a complete JSON Schema or public API;
- the FAIR Station database tables;
- multiple-source reconciliation and merging;
- visits, funding, permits, outputs, or activity logs;
- controlled vocabularies for activity types, roles, or statuses; or
- enrichment through ORCID, ROR, or other services.

These should be added when a tested workflow requires them.
