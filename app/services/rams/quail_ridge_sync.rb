module Rams
  # Coordinates retrieval, atomic persistence and validation evidence.
  class QuailRidgeSync
    def initialize(client:, output: $stdout, today: Date.current, configuration: Configuration.load, evidence_store: EvidenceStore.new)
      @client, @output, @today = client, output, today
      @configuration, @evidence_store = configuration, evidence_store
    end

    def call
      snapshot = Snapshot.pull(client: @client, configuration: @configuration, today: @today)
      snapshot.verify!(client: @client)
      log_counts(snapshot)
      @evidence_store.capture(snapshot) do |paths|
        ApplicationRecord.transaction { import(snapshot, paths) }
      end
    end

    private

    def import(snapshot, paths)
      records = RecordImport.new(snapshot: snapshot).call
      report = ValidationReport.new(snapshot: snapshot, records: records, evidence: paths).to_h
      @evidence_store.write_report(paths, report)
      report
    end

    def log_counts(snapshot)
      snapshot.counts.each do |resource, counts|
        @output.puts "#{resource}: pulled #{counts.fetch(:pulled)} / RAMS #{counts.fetch(:rams)}"
      end
    end
  end
end
