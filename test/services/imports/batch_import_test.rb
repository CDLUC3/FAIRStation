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
  test "the draft ORCID policy reuses an existing person without matching names" do
    existing = Person.create!(name: "Earlier name", orcid: "0000-0002-1825-0097")
    input = batch.people.sole.with(attributes: { name: "Current source name", orcid: "https://orcid.org/0000-0002-1825-0097" })
    import(batch.with(people: [ input ]))
    assert_equal 1, Person.count
    assert_equal existing, SourceIdentifier.find_by!(record_type: "Person", external_id: "person-a").record
    assert_equal "Current source name", existing.reload.name
  end

  test "the draft ORCID policy can associate two source IDs with one person" do
    first = batch.people.sole.with(attributes: { name: "Same person", orcid: "0000-0002-1825-0097" })
    second = first.with(external_id: "person-b")
    import(batch.with(people: [ first, second ]))
    assert_equal 1, Person.count
    assert_equal 2, Person.sole.source_identifiers.count
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

  test "long thesis titles survive persistence without truncation" do
    title = "Thesis " * 50
    activity = batch.activities.sole.with(attributes: batch.activities.sole.attributes.merge(thesis_title: title))
    import(batch.with(activities: [ activity ]))
    assert_equal title, ResearchActivity.sole.thesis_title
  end
end
