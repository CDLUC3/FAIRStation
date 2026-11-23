require_relative "../../support/rams_import_test_case"

class Rams::ImportEvidenceTest < RamsImportTestCase
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

  test "new stations and archives retain the supplied coordinates" do
    @station.destroy!
    result = sync
    assert_equal "122.149444", Station.sole.longitude.to_s("F")
    saved = JSON.parse(File.read(result.fetch(:evidence).fetch(:snapshot)))
    assert_equal 122.149444, saved.fetch("reserves").fetch("data").sole.fetch("longitude")
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
