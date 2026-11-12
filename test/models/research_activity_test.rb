require "test_helper"

class ResearchActivityTest < ActiveSupport::TestCase
  test "requires at least one station and supports multiple stations" do
    activity = ResearchActivity.new(title: "Oak regeneration")
    assert_not activity.valid?
    assert_includes activity.errors[:stations], "can't be blank"

    stations = [ Station.create!(name: "Quail Ridge"), Station.create!(name: "Other Reserve") ]
    activity.stations = stations
    activity.save!

    assert_equal stations, activity.reload.stations.order(:id).to_a
    stations.each { |station| assert_includes station.research_activities, activity }
  end

  test "preserves nullable project details and open source values" do
    activity = ResearchActivity.create!(stations: [ Station.create!(name: "Quail Ridge") ],
      status: "open", activity_type: "research", description: "Oak survey", keywords: "oak, regeneration",
      taxonomic_keywords: "Quercus", start_date: "2026-01-01", end_date: "2026-12-31")

    assert_nil activity.reload.title
    assert_equal "Oak survey", activity.description
    assert_equal "Quercus", activity.taxonomic_keywords
    assert_equal Date.new(2026, 1, 1), activity.start_date
    activity.update!(status: "future_status", activity_type: "campaign")
  end

  test "destroy removes joins and their source identifiers but preserves people and stations" do
    station = Station.create!(name: "Quail Ridge")
    activity = ResearchActivity.create!(stations: [ station ])
    person = Person.create!(name: "Researcher", orcid: "0000-0002-1825-0097")
    membership = activity.activity_people.create!(person: person, role: "faculty")
    records = [ activity, membership, activity.activity_stations.first ]
    identifiers = records.each_with_index.map do |record, i|
      record.source_identifiers.create!(source_system: "rams", source_instance: "ucnature", external_id: "record-#{i}")
    end

    activity.destroy!

    assert_empty ActivityPerson.where(research_activity_id: activity.id)
    assert_empty ActivityStation.where(research_activity_id: activity.id)
    assert_empty SourceIdentifier.where(id: identifiers.map(&:id))
    assert Person.exists?(person.id)
    assert Station.exists?(station.id)
  end
end
