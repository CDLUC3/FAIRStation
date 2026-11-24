require_relative "rams_collections"
require_relative "rams_client"

module RamsImport
  extend ActiveSupport::Concern

  include RamsCollections

  included do
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
  end

  def sync(archive: Imports::SourceArchive.new(directory: @evidence_directory))
    Imports::Sync.new(adapter: @adapter, client: @client, archive: archive).call
  end
end
