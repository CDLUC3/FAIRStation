require "test_helper"
require_relative "../../support/rams_collections"
require_relative "../../support/rams_client"

class Rams::ImportWorkflowTest < ActiveSupport::TestCase
  include RamsCollections

  setup do
    @connection = SourceConnection.load(:ucnature)
    @adapter = Rams::Adapter.new(connection: @connection, reserve_id: 27)
    @evidence_directory = Dir.mktmpdir("rams-test-")
    @station = Station.create!(name: "Quail Ridge Reserve", longitude: "-122.149444", doi: "10.21973/N30T0K")
    @station.source_identifiers.create!(**@adapter.source, external_id: "27")
    @rows = rams_rows
    @client = RamsTestClient.new(@rows)
  end

  teardown { FileUtils.remove_entry(@evidence_directory) }

  def sync(archive: Imports::SourceArchive.new(directory: @evidence_directory))
    Imports::Sync.new(adapter: @adapter, client: @client, archive: archive).call
  end

  test "shared identity memberships can change roles together on a later run" do
    other = @rows.fetch("team_memberships").first.deep_dup
    other["id"] = 28
    @rows.fetch("team_memberships") << other
    sync
    assert_equal 1, ActivityPerson.count
    @rows.fetch("team_memberships").each { |row| row["user_role"] = "postdoc" }
    sync
    assert_equal "postdoc", ActivityPerson.sole.role
    assert_equal 2, ActivityPerson.sole.source_identifiers.count
  end

  test "conflicting incoming memberships roll back without changing the existing role" do
    sync
    other = @rows.fetch("team_memberships").first.deep_dup
    other["id"] = 28
    other["user_role"] = "postdoc"
    @rows.fetch("team_memberships") << other
    assert_raises(Imports::Error) { sync }
    assert_equal "graduate_student", ActivityPerson.sole.role
    assert_equal 1, ActivityPerson.sole.source_identifiers.count
  end

  test "snapshot write failure prevents import" do
    file = File.join(@evidence_directory, "not-a-directory")
    File.write(file, "occupied")
    assert_raises(Errno::EEXIST) { sync(archive: Imports::SourceArchive.new(directory: file)) }
    assert_empty ResearchActivity.all
    assert_empty Person.all
  end

  test "evidence records retrieval time and typed source IDs in restricted local files" do
    result = sync
    paths = result.fetch(:evidence)
    paths.each_value { |path| assert_equal 0o600, File.stat(path).mode & 0o777 }
    assert_equal 0o700, File.stat(File.dirname(paths.fetch(:metadata))).mode & 0o777
    saved = JSON.parse(File.read(paths.fetch(:metadata)))
    assert_equal result.fetch(:retrieved_at), saved.fetch("retrieved_at")
    assert_equal @rows.fetch("projects"), JSON.parse(File.read(paths.fetch(:snapshot))).fetch("projects").fetch("data")
    assert_equal @adapter.source.stringify_keys, saved.fetch("source_identity")
  end

  test "all HTTP reads finish before entering the import transaction" do
    depth = ApplicationRecord.connection.open_transactions
    sync
    assert_equal [ depth ], @client.transaction_depths.uniq
  end

  test "unchanged repeat runs do not add SELECTs per project or repeated user" do
    sync
    small = count_selects { sync }
    originals = @rows.fetch("projects").deep_dup
    @rows["projects"] += (100..155).map { |id| originals.first.merge("id" => id, "title" => "Project #{id}") }
    sync
    large = count_selects { sync }
    assert_operator small, :<, 20
    assert_operator large, :<=, small + 2
    assert_equal 1, Person.count
  end

  test "conflicting ORCID assertions for the same user are not silently deduplicated" do
    @rows.fetch("projects").first["owner"] = @rows.fetch("projects").first.fetch("owner").merge("orcid" => "0000-0001-2345-6789")
    assert_raises(Rams::Error) { sync }
    assert_empty Person.all
    assert_empty ResearchActivity.all
  end

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
    assert_equal %w[reserves projects team_memberships visits fundings institutions], @client.requests.first(6).map(&:first)
    assert_equal({ reserve_id: 27 }, @client.requests[1].last)
  end

  test "an asserted ORCID collision stops the import and removes its archive" do
    existing = Person.create!(name: "Earlier name", orcid: "0000-0002-1825-0097")
    assert_raises(Imports::Error) { sync }
    assert_equal [ existing ], Person.all.to_a
    assert_equal "Earlier name", existing.reload.name
    assert_empty existing.source_identifiers
    assert_empty ResearchActivity.all
    assert_empty Dir.children(@evidence_directory)
  end

  test "names alone never merge source identities" do
    @rows["projects"].last["applicant"] = { "id" => 28, "full_name" => "Researcher", "orcid" => nil }
    @rows["team_memberships"] << @rows["team_memberships"].first.merge("id" => 28, "project" => { "id" => 34 }, "user" => @rows["projects"].last["applicant"])
    sync
    assert_equal 2, Person.count
    assert_equal [ "Researcher" ], Person.distinct.pluck(:name)
    people = SourceIdentifier.where(record_type: "Person", external_id: %w[27 28]).pluck(:record_id)
    assert_equal 2, people.uniq.size
  end

  test "new stations and archives retain the supplied coordinates" do
    @station.destroy!
    result = sync
    assert_equal "122.149444", Station.sole.longitude.to_s("F")
    saved = JSON.parse(File.read(result.fetch(:evidence).fetch(:snapshot)))
    assert_equal 122.149444, saved.fetch("reserves").fetch("data").sole.fetch("longitude")
  end

  test "unlinked owners and applicants remain in the archive without creating people" do
    @rows["projects"].last["applicant"] = { "id" => 28, "full_name" => "Unlinked applicant", "orcid" => nil }
    result = sync
    assert_equal 1, Person.count
    assert_not SourceIdentifier.exists?(record_type: "Person", external_id: "28")
    saved = JSON.parse(File.read(result.fetch(:evidence).fetch(:snapshot)))
    assert_equal 28, saved.fetch("projects").fetch("data").last.fetch("applicant").fetch("id")
  end

  test "empty projects and missing selected reserves stop before any writes" do
    @rows["projects"] = []
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
    @rows["reserves"] = [ { "id" => 3, "name" => "Other reserve" } ]
    assert_raises(Rams::Error) { sync }
    assert_equal 1, @client.requests.count { |resource, _| resource == "projects" }
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

  test "out of scope projects stop before writes" do
    @rows["projects"].first["reserve"]["id"] = 900
    assert_raises(Rams::Error) { sync }
    assert_empty ResearchActivity.all
  end

  test "visits use their own reserve scope even when their project is outside the pull" do
    @rows["visits"].first["project"]["id"] = 900
    sync
    assert_equal 8, ResearchActivity.count
    @rows["visits"].first["reserve"]["id"] = 3
    assert_raises(Rams::Error) { sync }
  end

  test "conflicting ORCIDs roll back the entire import" do
    person = Person.create!(name: "Earlier", orcid: "0000-0001-2345-6789")
    person.source_identifiers.create!(**@adapter.source, external_id: "27")
    assert_raises(Imports::Error) { sync }
    assert_empty ResearchActivity.all
    assert_equal "Earlier", person.reload.name
  end

  test "a late failure rolls back all imported records" do
    @rows["team_memberships"].first["active"] = nil
    assert_raises(ActiveRecord::RecordInvalid) { sync }
    assert_empty ResearchActivity.all
    assert_empty Person.all
    assert_empty ActivityPerson.all
  end
end
