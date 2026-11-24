require "test_helper"
require_relative "../../support/rams_import"

class Rams::ImportScopeTest < ActiveSupport::TestCase
  include RamsImport

  test "empty projects and missing selected reserves stop before any writes" do
    @rows["projects"] = []
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
    @rows["reserves"] = [ { "id" => 3, "name" => "Other reserve" } ]
    assert_raises(Rams::Error) { sync }
    assert_equal 1, @client.requests.count { |resource, _| resource == "projects/27" }
  end

  test "discovers metadata and excludes other reserves and their memberships" do
    @rows["reserves"].first["name"] = "Updated source name"
    @rows["reserves"] << { "id" => 3, "name" => "Other reserve" }
    foreign = @rows["team_memberships"].first.deep_dup
    foreign["id"] = 900
    foreign["project"]["id"] = 900
    foreign["user"] = { "id" => 900, "full_name" => "Outside selection", "orcid" => nil }
    @rows["team_memberships"] << foreign
    sync
    assert_equal 1, Station.count
    assert_equal 1, Person.count
    assert_equal 1, ActivityPerson.count
    assert_equal "Quail Ridge Reserve", @station.reload.name
  end

  test "imports another reserve using the same adapter and discovered station metadata" do
    @adapter = Rams::Adapter.new(connection: @connection, reserve_id: 3)
    @rows["reserves"].first.merge!("id" => 3, "name" => "Another reserve", "short_name" => "Another")
    @rows["projects"].each { |row| row["reserve"] = { "id" => 3, "name" => "Another reserve" } }
    %w[visits fundings].each { |resource| @rows[resource].each { |row| row["reserve"]["id"] = 3 } }
    sync
    station = SourceIdentifier.find_by!(**@connection.source, record_type: "Station", external_id: "3").record
    assert_equal "Another reserve", station.name
    assert_equal "Another", station.short_name
    assert_equal [ station ], ResearchActivity.first.stations.to_a
    assert_equal 2, Station.count
  end

  test "visit-linked projects can have no assigned reserve or belong elsewhere" do
    @rows["projects"][0]["reserve"] = nil
    @rows["projects"][1]["reserve"] = { "id" => 900 }
    @rows["projects"] << @rows["projects"].last.merge("id" => 999)
    sync
    assert_equal 8, ResearchActivity.count
    assert_equal [ @station.id ], ActivityStation.distinct.pluck(:station_id)
    assert_not SourceIdentifier.exists?(record_type: "ResearchActivity", external_id: "999")
  end

  test "inaccessible visit-linked projects stop before writes or archives" do
    @rows["visits"].first["project"]["id"] = 900
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
    assert_empty ImportRun.all
    assert_empty Dir.children(@evidence_directory)
  end

  test "out of scope visits stop before fetching projects" do
    @rows["visits"].first["reserve"]["id"] = 3
    assert_raises(Rams::Error) { sync }
    assert_not @client.requests.any? { |resource, _| resource.start_with?("projects/") }
    assert_empty ResearchActivity.all
  end

  test "a shared project keeps both station links across repeated syncs" do
    sync
    @adapter = Rams::Adapter.new(connection: @connection, reserve_id: 3)
    @rows["reserves"] << @rows["reserves"].first.merge("id" => 3, "name" => "Second station")
    @rows["visits"].each { |row| row["reserve"]["id"] = 3 }
    @rows["fundings"] = []
    2.times { sync }
    assert_equal 8, ResearchActivity.count
    assert_equal 2, Station.count
    assert_equal 16, ActivityStation.count
    assert_equal 1, Person.count
    assert_equal 1, ActivityPerson.count
  end

  test "a station with no visits completes an empty sync" do
    @rows["visits"] = []
    result = sync
    assert_empty ResearchActivity.all
    assert_equal 0, result.fetch(:imported).fetch("ResearchActivity")
    assert_equal 1, ImportRun.count
  end
end
