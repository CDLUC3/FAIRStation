require "test_helper"
require "stringio"

class Rams::QuailRidgeSyncTest < ActiveSupport::TestCase
  class Client
    attr_reader :requests, :rows

    def initialize(rows)
      @rows, @requests = rows, []
    end

    def collection(resource, **filters)
      @requests << [ resource, filters ]
      data = @rows.fetch(resource)
      { "data" => data, "total_count" => data.size }
    end

    def record(resource, id)
      @rows.fetch(resource).find { |row| row.fetch("id") == id }.deep_dup
    end
  end

  setup do
    @station = Station.create!(name: "Quail Ridge Reserve", longitude: "-122.149444", doi: "10.21973/N30T0K")
    @station.source_identifiers.create!(**Rams::QuailRidgeSync::SOURCE, external_id: "27")
    user = { "id" => 27, "type" => "users", "full_name" => "Researcher", "orcid" => "0000-0002-1825-0097" }
    @rows = {
      "reserves" => [ { "id" => 27, "name" => "Quail Ridge Reserve", "short_name" => "Quail", "description" => "", "doi" => "doi:10.21973/N30T0K", "latitude" => 38.48, "longitude" => 122.149444 } ],
      "projects" => (27..34).map do |id|
        Rams::QuailRidgeSync::PROJECT_FIELDS.keys.index_with { nil }.merge(
          "id" => id, "title" => "Project #{id}", "abstract" => "Research context", "project_type" => "research",
          "status" => id < 30 ? "open" : "closed", "reserve" => { "id" => 27, "name" => "Quail Ridge Reserve" },
          "owner" => user, "applicant" => nil, "created_at" => "2020-01-01T00:00:00Z", "future_field" => "visible loss"
        )
      end,
      "team_memberships" => [ { "id" => 27, "project" => { "id" => 27 }, "user" => user,
                                "user_role" => "graduate_student", "active" => false, "is_principal_investigator" => true,
                                "institution" => { "id" => 2, "name" => "University" } } ],
      "visits" => [ { "id" => 1, "reserve" => { "id" => 27 }, "project" => { "id" => 27 }, "status" => "approved" } ],
      "fundings" => [ { "id" => 1, "reserve" => { "id" => 27 }, "project" => { "id" => 27 }, "grant_number" => "123" } ],
      "institutions" => [ { "id" => 2, "name" => "University", "ror" => { "ror_id" => "https://ror.org/example" } } ]
    }
    @client = Client.new(@rows)
  end

  def sync
    Rams::QuailRidgeSync.new(client: @client, output: StringIO.new, today: Date.new(2026, 11, 12)).call
  end

  test "imports the graph, nullable ORCIDs, roles and source namespaces without duplicating reruns" do
    @rows["projects"].last["applicant"] = { "id" => 28, "full_name" => "No ORCID", "orcid" => nil }
    @rows["projects"].first["thesis_title"] = "Long thesis title " * 30
    @rows["projects"].first["submitted_at"] = "2026-01-01T12:34:56Z"
    report = sync
    assert_equal 8, ResearchActivity.count
    assert_equal 2, Person.count
    assert_nil Person.find_by!(name: "No ORCID").orcid
    activity = SourceIdentifier.find_by!(record_type: "ResearchActivity", external_id: "27").record
    assert_equal "Research context", activity.description
    assert_equal "Long thesis title " * 30, activity.thesis_title
    assert_equal Time.utc(2026, 1, 1, 12, 34, 56), activity.submitted_at
    assert_equal [ @station ], activity.stations.to_a
    membership = activity.activity_people.sole
    assert_equal "graduate_student", membership.role
    assert_not membership.active
    assert membership.is_principal_investigator
    assert_equal "Researcher", membership.person.name
    assert_equal "-122.149444", @station.reload.longitude.to_s("F")
    assert_equal "10.21973/N30T0K", @station.doi
    counts = [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count, SourceIdentifier.count ]
    sync
    assert_equal counts, [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count, SourceIdentifier.count ]
    assert_equal 8, report[:spot_checks].size
    assert report[:spot_checks].all? { |check| check[:fields]["owner"][:fields].values.all? { |field| field[:matches] } }
    assert_equal({ current: 0, historical: 0 }, report[:sample_shortfall])
    assert_equal %w[reserves projects team_memberships visits fundings institutions], @client.requests.first(6).map(&:first)
    assert_equal({ reserve_id: 27 }, @client.requests[1].last)
  end

  test "reports unsupported and unknown fields including nested IDs and curated station differences" do
    report = sync
    assert_includes report[:dropped_fields]["projects"], "future_field"
    assert_includes report[:dropped_fields]["fundings"], "grant_number"
    assert_includes report[:dropped_fields]["institutions"], "ror.ror_id"
    assert_includes report[:dropped_fields]["team_memberships"], "institution.id"
    assert_includes report[:station_differences_preserved], "longitude"
    assert_equal({ "owner" => 8, "applicant" => 0 }, report[:unmodeled_relationships])
    assert_equal Rams::QuailRidgeSync::PROJECT_FIELDS.keys.sort,
      report[:spot_checks].first[:fields].select { |_, field| field[:disposition].start_with?("mapped") }.keys.sort
  end

  test "ORCID matches an existing person and never merges people by name" do
    existing = Person.create!(name: "Earlier name", orcid: "0000-0002-1825-0097")
    @rows["projects"].last["applicant"] = { "id" => 28, "full_name" => "Researcher", "orcid" => nil }
    sync
    assert_equal 2, Person.count
    assert_equal existing, SourceIdentifier.find_by!(record_type: "Person", external_id: "27").record
  end

  test "empty projects and broader or wrong scopes stop before any writes" do
    @rows["projects"] = []
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
    @rows["reserves"] << { "id" => 3 }
    assert_raises(Rams::Error) { sync }
    assert_equal 1, @client.requests.count { |resource, _| resource == "projects" }
  end

  test "foreign projects and memberships stop before writes" do
    @rows["team_memberships"].first["project"]["id"] = 900
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
  end

  test "visits use their own reserve scope and report projects outside the pull" do
    @rows["visits"].first["project"]["id"] = 900
    assert_equal [ { visit_id: 1, project_id: 900 } ], sync[:visits_with_projects_outside_pull]
    @rows["visits"].first["reserve"]["id"] = 3
    assert_raises(Rams::Error) { sync }
  end

  test "conflicting ORCIDs roll back the entire import" do
    person = Person.create!(name: "Earlier", orcid: "0000-0001-2345-6789")
    person.source_identifiers.create!(**Rams::QuailRidgeSync::SOURCE, external_id: "27")
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
    assert_equal "Earlier", person.reload.name
  end

  test "a sampled project changing during retrieval rolls back the import" do
    client = @client
    def client.record(resource, id)
      super.merge("title" => "Changed after collection")
    end
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
    assert_empty Person.all
  end

  test "a late failure rolls back all imported records" do
    @rows["team_memberships"].first["active"] = nil
    assert_raises(ActiveRecord::RecordInvalid) { sync }
    assert_empty ResearchActivity.all
    assert_empty Person.all
    assert_empty ActivityPerson.all
  end
end
