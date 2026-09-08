# FAIR Station

FAIR Station imports station-owned research context into a common, connected
research model. RAMS is the first reference integration; it is not FAIR
Station's domain model.

The current validation slice imports one RAMS research project with its team,
visits, visit participants, and host stations. It preserves source identity,
derives the first qualifying visit from explicit evidence, and stores the
connected result idempotently.

## Setup

Requirements: Ruby 4.0.6 and SQLite 3.

```sh
bin/setup --skip-server
bin/rails test
```

Run the server with `bin/rails server` (or run `bin/setup` without
`--skip-server`). Pulling from RAMS requires:

- `RAMS_BASE_URL`: the RAMS application base URL;
- `RAMS_API_TOKEN`: an optional bearer token.

The provisional RAMS endpoint is
`GET /api/fair_station/v1/research_activities/:source_id`. Ask FAIR Station to
pull and import a record with:

```sh
bin/rails 'fair_station:import[rams,projects/123]'
```

The command reports the FAIR Station identifier. The stored connected
representation can subsequently be read from `GET /research_activities/:id`.

## Architecture

- `app/clients/http_client.rb`: source-independent HTTP and JSON mechanics;
- `app/adapters`: source selection, requests, and explicit source mapping;
- `app/operations/import_research_activity.rb`: the pull workflow and
  transaction boundary;
- `app/models`: persisted domain state and relational invariants;
- `lib/tasks/fair_station.rake`: the initial import trigger; and
- `app/serializers` and `app/controllers`: read-only JSON presentation.

There is intentionally no base adapter. A second working source integration
must reveal which adapter behavior is genuinely shared before a common protocol
or superclass is extracted.

See the [research record contract](docs/fair_station_research_record_contract.md)
and [ADR 0001](docs/decisions/0001-bootstrap-rails-validation-slice.md).
