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
    result = sync
    assert_equal 1, ActivityPerson.count
    assert_equal 1, result.fetch(:imported).fetch("ActivityPerson")
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

  test "a rerun stores the reported affiliation on each project membership" do
    first = @rows.fetch("team_memberships").sole
    institution = first["institution"]
    first["institution"] = nil
    sync
    existing = ActivityPerson.sole
    assert_nil existing.affiliation_source_id
    assert_nil existing.affiliation_name
    assert_nil existing.affiliation_ror_id

    first["institution"] = institution
    @rows.fetch("team_memberships") << first.merge(
      "id" => 28, "project" => { "id" => 34 }, "institution" => { "id" => 3, "name" => "Another University" }
    )
    result = sync

    assert_equal 1, Person.count
    assert_equal 2, existing.person.activity_people.count
    assert_equal "2", existing.reload.affiliation_source_id
    assert_equal "University", existing.affiliation_name
    assert_equal "https://ror.org/example", existing.affiliation_ror_id
    assert_equal result.fetch(:import_run_id), existing.source_identifiers.sole.import_run_id

    other = SourceIdentifier.find_by!(record_type: "ActivityPerson", external_id: "28").record
    assert_equal "3", other.affiliation_source_id
    assert_equal "Another University", other.affiliation_name
    assert_nil other.affiliation_ror_id
  end

  test "conflicting affiliations for one membership leave the previous import intact" do
    result = sync
    original = @rows.fetch("team_memberships").sole
    @rows.fetch("team_memberships") << original.merge(
      "id" => 28, "institution" => { "id" => 3, "name" => "Another University" }
    )

    error = assert_raises(Imports::Error) { sync }
    assert_match(/Conflicting incoming memberships/, error.message)
    membership = ActivityPerson.sole
    assert_equal "2", membership.affiliation_source_id
    assert_equal result.fetch(:import_run_id), membership.source_identifiers.sole.import_run_id
    assert_equal result.fetch(:import_run_id), ImportRun.sole.id
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
    @rows["visits"] += (100..155).map { |id| @rows["visits"].first.merge("id" => id, "project" => { "id" => id }) }
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
    assert_equal %w[reserves visits], @client.requests.first(2).map(&:first)
    assert_equal({ reserve_id: 27 }, @client.requests[1].last)
    assert_equal (27..34).map { |id| "projects/#{id}" }, @client.requests.map(&:first).grep(%r{projects/}).first(8)
    assert_not @client.requests.any? { |resource, _| resource == "projects" }
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

  test "imported counts include only distinct records processed by this run" do
    first = sync
    assert_equal({ "Station" => 1, "ResearchActivity" => 8, "Person" => 1, "ActivityPerson" => 1 }, first.fetch(:imported))
    @adapter = Rams::Adapter.new(connection: @connection, reserve_id: 3)
    @rows["reserves"].sole.merge!("id" => 3, "name" => "Another reserve")
    user = { "id" => 900, "full_name" => "Another researcher", "orcid" => nil }
    @rows["projects"] = [ @rows["projects"].first.merge("id" => 900, "reserve" => { "id" => 3 }, "owner" => user) ]
    @rows["team_memberships"] = [ @rows["team_memberships"].sole.merge("id" => 900, "project" => { "id" => 900 }, "user" => user) ]
    %w[visits fundings].each do |resource|
      @rows[resource].each { |row| row.merge!("reserve" => { "id" => 3 }, "project" => { "id" => 900 }) }
    end
    expected = { "Station" => 1, "ResearchActivity" => 1, "Person" => 1, "ActivityPerson" => 1 }
    assert_equal expected, sync.fetch(:imported)
    assert_equal [ 2, 9, 2, 2 ], [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count ]
    assert_equal expected, sync.fetch(:imported)
    assert_equal [ 2, 9, 2, 2 ], [ Station.count, ResearchActivity.count, Person.count, ActivityPerson.count ]
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

  test "conflicting ORCIDs roll back the entire import" do
    person = Person.create!(name: "Earlier", orcid: "0000-0001-2345-6789")
    person.source_identifiers.create!(**@adapter.source, external_id: "27")
    assert_raises(Imports::Error) { sync }
    assert_empty ResearchActivity.all
    assert_equal "Earlier", person.reload.name
  end

  test "successful sync receipts link records to verifiable evidence and advance freshness" do
    travel_to Time.utc(2026, 11, 18, 12) do
      first = sync
      receipt = ImportRun.find(first.fetch(:import_run_id))
      assert_equal Time.current, receipt.successful_at
      assert_equal Time.current, receipt.retrieved_at
      assert_equal Digest::SHA256.file(receipt.snapshot_path).hexdigest, receipt.snapshot_sha256
      assert_equal Digest::SHA256.file(receipt.metadata_path).hexdigest, receipt.metadata_sha256
      assert_equal [ receipt.id ], SourceIdentifier.distinct.pluck(:import_run_id)
      travel 1.hour
      second = sync
      assert_equal Time.current, ImportRun.last_successful_sync(source: @adapter.source, station_external_id: 27)
      assert_equal [ second.fetch(:import_run_id) ], SourceIdentifier.distinct.pluck(:import_run_id)
      assert_equal 2, ImportRun.count
      assert File.exist?(receipt.snapshot_path)
      assert_nil ImportRun.last_successful_sync(source: @adapter.source, station_external_id: 3)
    end
  end

  test "failed repeat sync preserves last successful receipt and archive" do
    first = sync
    receipt = ImportRun.find(first.fetch(:import_run_id))
    @rows["team_memberships"].first["active"] = nil
    assert_raises(ActiveRecord::RecordInvalid) { sync }
    assert_equal [ receipt.id ], ImportRun.pluck(:id)
    assert_equal [ receipt.id ], SourceIdentifier.distinct.pluck(:import_run_id)
    assert_equal receipt.successful_at, ImportRun.last_successful_sync(source: @adapter.source, station_external_id: 27)
    assert_equal 1, Dir.children(@evidence_directory).size
    assert File.exist?(receipt.snapshot_path)
  end

  test "a late failure rolls back all imported records" do
    @rows["team_memberships"].first["active"] = nil
    assert_raises(ActiveRecord::RecordInvalid) { sync }
    assert_empty ResearchActivity.all
    assert_empty Person.all
    assert_empty ActivityPerson.all
    assert_empty ImportRun.all
    assert_empty Dir.children(@evidence_directory)
  end
end
