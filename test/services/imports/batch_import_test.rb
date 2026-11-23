require "test_helper"

class Imports::BatchImportTest < ActiveSupport::TestCase
  def batch(instance: "installation-a", station_id: "station-a", title: "Translated activity")
    Imports::Batch.new(source: { source_system: "another_source", source_instance: instance },
      stations: [ Imports::Batch::StationInput.new(external_id: station_id, attributes: { name: "Translated station" }) ],
      people: [ Imports::Batch::PersonInput.new(external_id: "person-a", attributes: { name: "Translated person", orcid: nil }) ],
      activities: [ Imports::Batch::ActivityInput.new(external_id: "activity-a", attributes: { title: title, activity_type: "research", status: "open" }, station_ids: [ station_id ]) ],
      memberships: [ Imports::Batch::MembershipInput.new(external_id: "membership-a", attributes: { role: "researcher", active: true, is_principal_investigator: false }, activity_id: "activity-a", person_id: "person-a") ])
  end

  def import(batch)
    ApplicationRecord.transaction { Imports::BatchImport.new(batch: batch).call }
  end

  test "imports translated records from another source and safely refreshes reruns" do
    import(batch)
    activity = ResearchActivity.sole
    assert_equal "Translated person", activity.people.sole.name
    assert_equal "Translated station", activity.stations.sole.name
    assert_equal "researcher", activity.activity_people.sole.role
    import(batch(title: "Refreshed activity"))
    assert_equal "Refreshed activity", activity.reload.title
    assert_equal 1, ResearchActivity.count
    assert_equal 1, Person.count
    assert_equal 1, ActivityPerson.count
    assert_equal 4, SourceIdentifier.count
  end

  test "station selections share identities within an installation" do
    import(batch)
    import(batch(station_id: "station-b"))
    assert_equal 2, Station.count
    assert_equal 1, Person.count
    assert_equal 1, ResearchActivity.count
    assert_equal 1, ActivityPerson.count
    assert_equal 2, ResearchActivity.sole.stations.count
    import(batch)
    assert_equal 2, ResearchActivity.sole.stations.count
  end

  test "membership role names are interpreted by the source" do
    original = batch
    row = original.memberships.sole
    owner = row.with(attributes: row.attributes.merge(role: "owner"))
    import(original.with(memberships: [ owner ]))
    membership = ActivityPerson.sole

    import(original)

    assert_equal membership, ActivityPerson.sole
    assert_equal "researcher", membership.reload.role
  end

  test "identical external IDs from another installation remain distinct" do
    import(batch)
    import(batch(instance: "installation-b"))
    assert_equal 2, Station.count
    assert_equal 2, Person.count
    assert_equal 2, ResearchActivity.count
    assert_equal 2, ActivityPerson.count
  end

  test "missing source references fail atomically" do
    incoming = batch.with(stations: [])
    assert_raises(Imports::Error) { import(incoming) }
    assert_empty Person.all
    assert_empty ResearchActivity.all
    assert_empty SourceIdentifier.all
  end
  test "an asserted ORCID cannot link a new source identity to an existing person" do
    existing = Person.create!(name: "Earlier name", orcid: "0000-0002-1825-0097")
    input = batch.people.sole.with(attributes: { name: "Current source name", orcid: "https://orcid.org/0000-0002-1825-0097" })
    assert_raises(Imports::Error) { import(batch.with(people: [ input ])) }
    assert_equal 1, Person.count
    assert_equal "Earlier name", existing.reload.name
    assert_empty SourceIdentifier.all
    assert_empty Station.all
    assert_empty ResearchActivity.all
  end

  test "two source identities asserting the same ORCID fail atomically" do
    first = batch.people.sole.with(attributes: { name: "Same person", orcid: "0000-0002-1825-0097" })
    second = first.with(external_id: "person-b")
    assert_raises(Imports::Error) { import(batch.with(people: [ first, second ])) }
    assert_empty Person.all
    assert_empty SourceIdentifier.all
    assert_empty Station.all
  end

  test "a known source identity can refresh attributes without an ORCID merge" do
    input = batch.people.sole.with(attributes: { name: "Earlier name", orcid: "0000-0002-1825-0097" })
    import(batch.with(people: [ input ]))
    person = Person.sole
    refreshed = input.with(attributes: { name: "Current source name", orcid: "https://orcid.org/0000-0002-1825-0097" })
    import(batch.with(people: [ refreshed ]))
    assert_equal person, Person.sole
    assert_equal "Current source name", person.reload.name
    assert_equal 1, person.source_identifiers.count
  end

  test "contradictory ORCID and source identities fail atomically" do
    input = batch.people.sole.with(attributes: { name: "Person", orcid: "0000-0002-1825-0097" })
    import(batch.with(people: [ input ]))
    conflicting = input.with(attributes: { name: "Changed", orcid: "0000-0001-2345-6789" })
    assert_raises(Imports::Error) { import(batch.with(people: [ conflicting ])) }
    assert_equal "Person", Person.sole.name
    assert_equal "0000-0002-1825-0097", Person.sole.orcid
  end

  test "curated station attributes are preserved on reruns" do
    import(batch)
    incoming = batch.stations.sole.with(attributes: { name: "Uncurated source name" })
    import(batch.with(stations: [ incoming ]))
    assert_equal "Translated station", Station.sole.name
  end

  test "receipt links only this batch and rejects a different source" do
    receipt = ImportRun.create!(**batch.source, station_external_id: "station-a",
      retrieved_at: 1.minute.ago, successful_at: Time.current,
      snapshot_path: "/archive/snapshot.json", metadata_path: "/archive/retrieval.json",
      snapshot_sha256: "a" * 64, metadata_sha256: "b" * 64)
    ApplicationRecord.transaction { Imports::BatchImport.new(batch: batch, import_run: receipt).call }
    assert_equal [ receipt.id ], SourceIdentifier.distinct.pluck(:import_run_id)
    assert_equal receipt.successful_at, ImportRun.last_successful_sync(source: batch.source, station_external_id: "station-a")
    assert_nil ImportRun.last_successful_sync(source: batch.source, station_external_id: "station-b")
    assert_raises(Imports::Error) { Imports::BatchImport.new(batch: batch(instance: "another"), import_run: receipt) }
  end

  test "long thesis titles survive persistence without truncation" do
    title = "Thesis " * 50
    activity = batch.activities.sole.with(attributes: batch.activities.sole.attributes.merge(thesis_title: title))
    import(batch.with(activities: [ activity ]))
    assert_equal title, ResearchActivity.sole.thesis_title
  end
end
