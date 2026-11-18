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
Owners and applicants without selected memberships are not emitted as people;
their relationships remain unmodeled. Assertions about selected people still
participate in ORCID consistency checks. Directory coordinates pass through
unchanged; corrections belong in the source data. Quail Ridge's known longitude
sign error is tracked in [ngRAMS #256](https://github.com/CDLUC3/ngRAMS/issues/256).

This layer does not retrieve source collections, persist records, reconcile
people by ORCID, or generate diagnostic reports. Repeated assertions about the
same RAMS user must agree on ORCID; this is input consistency, not cross-user
identity matching.

## Visit-based scope

A RAMS project is selected when it has at least one visit at the selected reserve,
past or scheduled. Assigned reserve and reserve interest do not select projects
or determine station links. Each selected activity links to the current station;
syncing another station visited by the same project adds that station as well.
Visits establish scope, not proof of attendance. No visit status is interpreted
as a human review decision. Missing visit-linked projects stop translation rather
than silently producing a partial import.

The retrieval layer must obtain all visit-linked projects using the token's API
permissions. Tests use synthetic data, including a project visiting two stations;
no live Sentinel Sites data was used. Production audit results stay private.
