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
    assert_equal({ role: "graduate_student", active: false, is_principal_investigator: true }, batch.memberships.sole.attributes)
  end

  test "another reserve uses the same mappings and directory metadata" do
    @adapter = Rams::Adapter.new(connection: SourceConnection.load(:ucnature), reserve_id: 3)
    @rows["reserves"].first.merge!("id" => 3, "name" => "Another reserve")
    @rows["projects"].each { |row| row["reserve"]["id"] = 3 }
    assert_equal "Another reserve", translate.stations.sole.attributes[:name]
    assert_equal [ 3 ], translate.activities.first.station_ids
  end

  test "memberships and their people outside selected projects are excluded" do
    @rows["team_memberships"] << { "id" => 900, "project" => { "id" => 900 }, "user" => { "id" => 900 } }
    assert_equal 1, translate.memberships.size
    assert_equal 1, translate.people.size
  end

  test "contradictory ORCID assertions for the same source person stop translation" do
    @rows["projects"].first["owner"] = @rows["projects"].first["owner"].merge("orcid" => "0000-0001-2345-6789")
    assert_raises(Rams::Error) { translate }
  end
end
