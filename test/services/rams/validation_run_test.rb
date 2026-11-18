require "test_helper"
require_relative "../../support/rams_collections"
require_relative "../../support/rams_client"

class Rams::ValidationRunTest < ActiveSupport::TestCase
  include RamsCollections

  setup do
    @directory = Dir.mktmpdir("rams-diagnostics-")
    @rows = rams_rows
    @adapter = Rams::Adapter.new(connection: SourceConnection.load(:ucnature), reserve_id: 27)
    @client = RamsTestClient.new(@rows)
    @archive = Imports::SourceArchive.new(directory: @directory)
    Imports::Sync.new(adapter: @adapter, client: @client, archive: @archive).call
  end

  teardown { FileUtils.remove_entry(@directory) }

  def validate(archive: @archive)
    Rams::ValidationRun.new(adapter: @adapter, client: @client, archive: archive, today: Date.new(2026, 11, 12)).call
  end

  test "writes a sample report and source references without any domain writes" do
    writes = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      writes << payload[:sql] if payload[:sql].match?(/\A(?:INSERT|UPDATE|DELETE)/i)
    end
    report = validate
    assert_empty writes
    assert_equal 8, report[:spot_checks].size
    assert_equal({ current: 0, historical: 0 }, report[:sample_shortfall])
    assert_not_includes report, :snapshot
    report[:evidence].each_value { |path| assert_equal 0o600, File.stat(path).mode & 0o777 }
    assert_equal 0o700, File.stat(File.dirname(report[:evidence][:report])).mode & 0o777
    saved = JSON.parse(File.read(report[:evidence][:report]))
    assert_equal report[:retrieved_at], saved["retrieved_at"]
    assert_equal @rows["projects"], JSON.parse(File.read(report[:evidence][:snapshot]))["projects"]["data"]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  test "accounts for unmapped fields, unselected rows, and unmodeled relationships" do
    @rows["reserves"] << { "id" => 3, "name" => "Another reserve" }
    @rows["team_memberships"] << { "id" => 900, "project" => { "id" => 900 }, "user" => { "id" => 900, "full_name" => "Outside selection" } }
    report = validate
    assert_includes report[:dropped_fields]["projects"], "future_field"
    assert_includes report[:dropped_fields]["fundings"], "grant_number"
    assert_includes report[:dropped_fields]["institutions"], "ror.ror_id"
    assert_equal 1, report[:memberships_outside_selection]
    assert_equal 1, report[:dropped_fields]["reserves"]["id"][:present]
    assert_equal 1, report[:dropped_fields]["team_memberships"]["user.full_name"][:present]
    assert_equal({ "owner" => 8, "applicant" => 0 }, report[:unmodeled_relationships])
  end

  test "curated station differences and outside project references are explicit" do
    Station.sole.update!(longitude: "-122.149444")
    @rows["visits"].first["project"]["id"] = 900
    report = validate
    assert_includes report[:station_differences_preserved], "longitude"
    assert_equal [ { visit_id: 1, project_id: 900 } ], report[:visits_with_projects_outside_pull]
  end

  test "sample shortfalls are reported" do
    @rows["projects"] = @rows["projects"].first(2)
    assert_equal({ current: 1, historical: 5 }, validate[:sample_shortfall])
  end

  test "changed source detail responses stop diagnostics without changing the import" do
    def @client.record(resource, id)
      super.merge("title" => "Changed since collection")
    end
    before = ResearchActivity.order(:id).pluck(:title)
    assert_raises(Rams::Error) { validate }
    assert_equal before, ResearchActivity.order(:id).pluck(:title)
  end

  test "a stored project field mismatch stops diagnostics" do
    activity = SourceIdentifier.find_by!(record_type: "ResearchActivity", external_id: "27").record
    activity.update!(description: "A different local description")
    assert_raises(Rams::Error) { validate }
    assert_equal "A different local description", activity.reload.description
  end

  class FailingArchive < Imports::SourceArchive
    def write_report(paths, report)
      raise IOError, "Report unavailable"
    end
  end

  test "report write failures clean only the diagnostic archive and preserve the earlier import" do
    before = Dir.children(@directory).sort
    assert_raises(IOError) { validate(archive: FailingArchive.new(directory: @directory)) }
    assert_equal before, Dir.children(@directory).sort
    assert_equal 8, ResearchActivity.count
    assert_equal 1, Person.count
    assert_equal 1, ActivityPerson.count
  end
end
