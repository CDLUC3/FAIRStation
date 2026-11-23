require "digest"

module Imports
  # Retrieves and translates before atomically persisting the proposed inputs.
  class Sync
    def initialize(adapter:, client:, archive: SourceArchive.new)
      @adapter, @client, @archive = adapter, client, archive
    end

    def call
      snapshot = @adapter.pull(client: @client)
      batch = @adapter.translate(collections: snapshot.collections)
      @archive.capture(snapshot) do |paths|
        persist(batch, snapshot, paths)
      end
    end

    private

    def persist(batch, snapshot, paths)
      ApplicationRecord.transaction do
        receipt = create_receipt(batch, snapshot, paths)
        records = BatchImport.new(batch: batch, import_run: receipt).call
        receipt.update!(successful_at: Time.current)
        { import_run_id: receipt.id, successful_at: receipt.successful_at, source: batch.source, retrieved_at: snapshot.retrieved_at,
          counts: snapshot.counts, imported: records.counts(batch: batch), evidence: paths }
      end
    end

    def create_receipt(batch, snapshot, paths)
      ImportRun.create!(**batch.source, station_external_id: batch.stations.sole.external_id.to_s,
        retrieved_at: snapshot.retrieved_at, successful_at: Time.current,
        snapshot_path: File.expand_path(paths.fetch(:snapshot)), metadata_path: File.expand_path(paths.fetch(:metadata)),
        snapshot_sha256: Digest::SHA256.file(paths.fetch(:snapshot)).hexdigest,
        metadata_sha256: Digest::SHA256.file(paths.fetch(:metadata)).hexdigest)
    end
  end
end
