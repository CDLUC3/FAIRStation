require "test_helper"
require_relative "../../support/rams_collections"

class Rams::AdapterTest < ActiveSupport::TestCase
  include RamsCollections

  setup do
    @adapter = Rams::Adapter.new(connection: SourceConnection.load(:ucnature), reserve_id: 27)
    @rows = rams_rows
  end

  def translate = @adapter.translate(collections: rams_collections(@rows))

  test "translates source fields into proposed FAIR Station inputs without persistence" do
    @rows["projects"].first["thesis_title"] = "A thesis title"
    batch = nil
    assert_no_difference [ "Station.count", "Person.count", "ResearchActivity.count", "SourceIdentifier.count" ] do
      batch = translate
    end
    assert_equal({ source_system: "rams", source_instance: "ucnature" }, batch.source)
    assert_equal "Research context", batch.activities.first.attributes[:description]
    assert_equal "research", batch.activities.first.attributes[:activity_type]
    assert_equal "A thesis title", batch.activities.first.attributes[:thesis_title]
    assert_equal [ 27 ], batch.activities.first.station_ids
    assert_equal "Quail Ridge Reserve", batch.stations.sole.attributes[:name]
    assert_equal({ name: "Researcher", orcid: "0000-0002-1825-0097" }, batch.people.sole.attributes)
    assert_equal 27, batch.memberships.sole.activity_id
    assert_equal 27, batch.memberships.sole.person_id
    assert_equal({
      role: "graduate_student", active: false, is_principal_investigator: true,
      affiliation_source_id: "2", affiliation_name: "University", affiliation_ror_id: "https://ror.org/example"
    }, batch.memberships.sole.attributes)
  end

  test "another reserve uses the same mappings and directory metadata" do
    @adapter = Rams::Adapter.new(connection: SourceConnection.load(:ucnature), reserve_id: 3)
    @rows["reserves"].first.merge!("id" => 3, "name" => "Another reserve")
    @rows["visits"].each { |row| row["reserve"]["id"] = 3 }
    assert_equal "Another reserve", translate.stations.sole.attributes[:name]
    assert_equal [ 3 ], translate.activities.first.station_ids
    assert_equal 122.149444, translate.stations.sole.attributes[:longitude]
  end

  test "passes directory coordinates through without changing source data" do
    assert_equal 122.149444, translate.stations.sole.attributes[:longitude]
    assert_equal 122.149444, @rows["reserves"].sole.fetch("longitude")
    @rows["reserves"].sole["longitude"] = -122.15
    assert_equal(-122.15, translate.stations.sole.attributes[:longitude])
  end

  test "another installation retains its directory coordinates" do
    connection = SourceConnection.load(:ucnature).with(source: { source_system: "rams", source_instance: "another" })
    @adapter = Rams::Adapter.new(connection: connection, reserve_id: 27)
    assert_equal 122.149444, translate.stations.sole.attributes[:longitude]
  end

  test "owners and applicants are emitted even without selected memberships" do
    @rows["projects"].first["owner"] = { "id" => 100, "full_name" => "Owner", "orcid" => nil }
    @rows["projects"].first["applicant"] = { "id" => 101, "full_name" => "Applicant", "orcid" => nil }
    assert_equal [ 27, 100, 101 ], translate.people.map(&:external_id).sort
    @rows["team_memberships"] = []
    batch = translate
    assert_equal [ 27, 100, 101 ], batch.people.map(&:external_id).sort
    assert_empty batch.memberships
    assert_equal({ "owner" => 100, "applicant" => 101 }, batch.assignments.select { |link| link.activity_id == 27 }.to_h { |link| [ link.role, link.person_id ] })
  end

  test "memberships and their people outside selected projects are excluded" do
    @rows["team_memberships"] << { "id" => 900, "project" => { "id" => 900 }, "user" => { "id" => 900 } }
    assert_equal 1, translate.memberships.size
    assert_equal 1, translate.people.size
  end

  test "visits select projects and attribute them regardless of assigned reserve" do
    @rows["projects"][0]["reserve"] = nil
    @rows["projects"][1]["reserve"] = { "id" => 3 }
    @rows["visits"] = @rows["visits"].first(2)
    batch = translate
    assert_equal [ 27, 28 ], batch.activities.map(&:external_id)
    assert_equal [ [ 27 ] ], batch.activities.map(&:station_ids).uniq
    assert_equal [ 27 ], batch.memberships.map(&:activity_id)
  end

  test "a project visiting several reserves is attributed to each selected station" do
    @rows["reserves"] << @rows["reserves"].first.merge("id" => 3)
    @rows["visits"] << @rows["visits"].first.merge("id" => 900, "reserve" => { "id" => 3 })
    assert_equal [ 27 ], translate.activities.first.station_ids
    @adapter = Rams::Adapter.new(connection: SourceConnection.load(:ucnature), reserve_id: 3)
    assert_equal [ 27 ], translate.activities.map(&:external_id)
    assert_equal [ 3 ], translate.activities.sole.station_ids
  end

  test "projects without visits do not import their people or memberships" do
    @rows["visits"] = []
    batch = translate
    assert_empty batch.activities
    assert_empty batch.memberships
    assert_empty batch.assignments
    assert_empty batch.people
  end

  test "missing visit-linked projects stop translation" do
    @rows["projects"].shift
    assert_raises(Rams::Error) { translate }
  end

  test "contradictory ORCID assertions for the same source person stop translation" do
    @rows["projects"].first["owner"] = @rows["projects"].first["owner"].merge("orcid" => "0000-0001-2345-6789")
    assert_raises(Rams::Error) { translate }
  end
end
