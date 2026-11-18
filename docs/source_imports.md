# Source imports

FAIR Station owns activities, people, stations and their relationships. Source
adapters translate an external format into proposed import inputs; persistence
and identity reconciliation are separate responsibilities.

## Adapter inputs

`Imports::Batch` groups station, person, activity and membership inputs under a
stable source-system/installation namespace. Each input carries a source ID,
FAIR Station attributes, and any source-local references needed to connect it.
These are not persisted domain records. Ruby `Data` defines their small value
classes without custom constructor/accessor boilerplate; nested attributes and
arrays are still mutable. The representation is a draft API for review.

`Rams::Adapter#translate(collections:)` accepts parsed collection responses and
returns a batch without HTTP or database writes. RAMS project `abstract` maps to
activity `description`, and `project_type` maps to `activity_type`. Reserve
metadata comes from the retrieved directory, not per-reserve YAML. Selected
membership references determine which people and roles are included.

This layer does not retrieve source collections, persist records, reconcile
people by ORCID, or generate diagnostic reports. Repeated assertions about the
same RAMS user must agree on ORCID; this is input consistency, not cross-user
identity matching.

## Scope decision still needed

RAMS allows projects with no assigned reserve and projects with visits at several
reserves. The caller must supply an agreed selection of projects. This adapter
currently uses each project's supplied reserve association for station links;
it does not infer links from visits or repair missing reserve assignments. API
selection and attribution need explicit review before the runnable import is
ready for use. Tests use synthetic data; production audit results stay private.

## Persistence and identity (draft)

`Imports::BatchImport` persists proposed attributes in dependency order: stations,
people, activities, then memberships. Its caller owns the database transaction.
`SourceIdentityMap` is a per-run lookup/cache from a typed external identifier
in one installation to its FAIR Station object. It batches lookups and stores
source identifiers; it is import infrastructure, not a new domain entity.

`PersonIdentity` is a separate policy. The current proposal reuses an existing
source identity, otherwise matches a normalized supplied ORCID; conflicting
source/ORCID identities stop the import. Several source IDs may identify one
Person. Names are not identity keys. A supplied ORCID is not independent identity
verification. Automatic cross-source ORCID association is a draft policy that
needs agreement before this layer is ready to merge.

Reruns preserve local object IDs and existing station values. Imported person,
activity and membership attributes can refresh. Removals, per-field human-edit
protection, and complete change history remain outside this slice (#33).
The thesis-title migration widens a string to text to avoid truncation; its
rollback is explicitly irreversible.
