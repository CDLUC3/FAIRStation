# AWS runtime parameters

The contract between deployment and the container. It follows UC3 practice
(`ngRAMS` Sceptre stacks) with one deliberate narrowing: exactly one secret
enters the container.

## Path convention

One SSM parameter path per environment:

- staging: `/uc3/fairstation/stg`

Parameters are `${BasePath}/${Key}`. Nothing in this repository stores their
values.

## Required, secret (`SecureString`)

| Container variable | SSM key | Purpose |
|---|---|---|
| `RAILS_MASTER_KEY` | `/uc3/fairstation/stg/RailsMasterKey` | Unlocks `config/credentials.yml.enc` |

`RAILS_MASTER_KEY` is the only application secret deployment supplies. The
database password, and later RAMS, Zotero, and ORCID credentials, live in Rails
encrypted credentials so that rotating them never adds an AWS parameter.

## Required, non-secret (`String`)

| Container variable | SSM key | Source |
|---|---|---|
| `DATABASE_HOST` | `/uc3/fairstation/stg/RdsHost` | `database` stack output |
| `DATABASE_PORT` | `/uc3/fairstation/stg/RdsPort` | `database` stack output |
| `DATABASE_NAME` | `/uc3/fairstation/stg/RdsName` | `database` stack output |
| `DATABASE_USERNAME` | `/uc3/fairstation/stg/RdsUsername` | `database` stack output |

The MySQL password is **not** a parameter. `config/database.yml` reads it from
`config/credentials.yml.enc` under `database.password`.

## Inline ECS environment

Non-secret runtime configuration belongs in the task definition, not in SSM:

```
RAILS_ENV=production
PORT=3000
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
```

## Adding a secret later

Put it in Rails credentials, then read it through `Rails.application.credentials`. Do
not create a new `SecureString` parameter: deployment must keep needing only the
master key. That covers the RAMS and Zotero keys named in the platform issue.

## Migrations

`db:prepare` runs as a one-off task before the web service starts, using the same
`RAILS_MASTER_KEY` and database variables. The migration task never receives a
database password directly; it decrypts credentials like the web task does.

## Rotation

- **Database password**: update `database.password` in credentials, deploy, then
  rotate the RDS user. Both tasks read the new value; no AWS parameter changes.
- **Master key**: generate a new key, re-encrypt the credentials file with it,
  update the `RailsMasterKey` `SecureString`, then restart the service. Keep the
  previous key available until the last task has restarted.
- **KMS**: the `SecureString` may use `alias/aws/ssm` or a customer-managed key.
  A customer-managed key requires `kms:Decrypt` on the execution role.

## Ownership

An AWS operator with account access creates the parameters once per environment.
They are never written by CI, never committed, and never printed by the
deployment pipeline.
