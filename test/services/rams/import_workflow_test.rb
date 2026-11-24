require "test_helper"
require_relative "../../support/rams_import"

class Rams::ImportWorkflowTest < ActiveSupport::TestCase
  include RamsImport

  test "unchanged repeat runs do not add SELECTs per project or repeated user" do
    sync
    small = count_selects { sync }
    originals = @rows.fetch("projects").deep_dup
    @rows["projects"] += (100..155).map { |id| originals.first.merge("id" => id, "title" => "Project #{id}") }
    @rows["visits"] += (100..155).map { |id| @rows["visits"].first.merge("id" => id, "project" => { "id" => id }) }
    sync
    large = count_selects { sync }
    assert_operator small, :<, 20
    assert_operator large, :<=, small + 2
    assert_equal 1, Person.count
  end

  test "imports the graph, nullable ORCIDs, roles and source namespaces without duplicating reruns" do
    @rows["projects"].last["applicant"] = { "id" => 28, "full_name" => "No ORCID", "orcid" => nil }
    @rows["team_memberships"] << @rows["team_memberships"].first.merge("id" => 28, "project" => { "id" => 34 }, "user" => @rows["projects"].last["applicant"])
    @rows["projects"].first["thesis_title"] = "Long thesis title " * 30
    @rows["projects"].first["submitted_at"] = "2026-01-01T12:34:56Z"
    sync
    assert_equal 8, ResearchActivity.count
    assert_equal 2, Person.count
    assert_nil Person.find_by!(name: "No ORCID").orcid
    activity = SourceIdentifier.find_by!(record_type: "ResearchActivity", external_id: "27").record
    assert_equal "Research context", activity.description
    assert_equal "Long thesis title " * 30, activity.thesis_title
    assert_equal Time.utc(2026, 1, 1, 12, 34, 56), activity.submitted_at
    assert_equal [ @station ], activity.stations.to_a
    membership = team_membership
    assert_equal "graduate_student", membership.role
    assert_not membership.active
    assert membership.is_principal_investigator
    assert_equal "Researcher", membership.person.name
    assert_equal "-122.149444", @station.reload.longitude.to_s("F")
    assert_equal "10.21973/N30T0K", @station.doi
    counts = [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count, SourceIdentifier.count ]
    sync
    assert_equal counts, [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count, SourceIdentifier.count ]
    assert_equal %w[reserves visits], @client.requests.first(2).map(&:first)
    assert_equal({ reserve_id: 27 }, @client.requests[1].last)
    assert_equal (27..34).map { |id| "projects/#{id}" }, @client.requests.map(&:first).grep(%r{projects/}).first(8)
    assert_not @client.requests.any? { |resource, _| resource == "projects" }
  end

  test "imported counts include only distinct records processed by this run" do
    first = sync
    assert_equal({ "Station" => 1, "ResearchActivity" => 8, "Person" => 1, "ActivityPerson" => 9 }, first.fetch(:imported))
    @adapter = Rams::Adapter.new(connection: @connection, reserve_id: 3)
    @rows["reserves"].sole.merge!("id" => 3, "name" => "Another reserve")
    user = { "id" => 900, "full_name" => "Another researcher", "orcid" => nil }
    @rows["projects"] = [ @rows["projects"].first.merge("id" => 900, "reserve" => { "id" => 3 }, "owner" => user) ]
    @rows["team_memberships"] = [ @rows["team_memberships"].sole.merge("id" => 900, "project" => { "id" => 900 }, "user" => user) ]
    %w[visits fundings].each do |resource|
      @rows[resource].each { |row| row.merge!("reserve" => { "id" => 3 }, "project" => { "id" => 900 }) }
    end
    expected = { "Station" => 1, "ResearchActivity" => 1, "Person" => 1, "ActivityPerson" => 2 }
    assert_equal expected, sync.fetch(:imported)
    assert_equal [ 2, 9, 2, 11 ], [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count ]
    assert_equal expected, sync.fetch(:imported)
    assert_equal [ 2, 9, 2, 11 ], [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count ]
  end

  private

  def count_selects
    count = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 if payload[:sql].match?(/\ASELECT/i) && !payload[:cached] && payload[:name] != "SCHEMA"
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
end
