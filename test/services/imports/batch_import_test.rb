require_relative "../../support/batch_import_test_case"

class Imports::BatchImportTest < BatchImportTestCase
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
