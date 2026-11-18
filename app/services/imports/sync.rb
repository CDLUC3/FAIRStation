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
        ApplicationRecord.transaction do
          records = BatchImport.new(batch: batch).call
          { source: batch.source, retrieved_at: snapshot.retrieved_at,
            counts: snapshot.counts, imported: records.counts, evidence: paths }
        end
      end
    end
  end
end
