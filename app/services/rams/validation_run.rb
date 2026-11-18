module Rams
  # Read-only comparison against an existing local import; never imports records.
  class ValidationRun
    def initialize(adapter:, client:, archive: Imports::SourceArchive.new, today: Date.current)
      @adapter, @client, @archive, @today = adapter, client, archive, today
    end

    def call
      snapshot = @adapter.pull(client: @client)
      samples = ProjectSamples.new(snapshot: snapshot, today: @today)
      samples.verify!(client: @client)
      records = Imports::SourceIdentityMap.new(source: @adapter.source)
      @archive.capture(snapshot) do |paths|
        paths = paths.merge(report: File.join(File.dirname(paths.fetch(:snapshot)), "report.json"))
        report = ValidationReport.new(snapshot: snapshot, records: records, samples: samples, evidence: paths).to_h
        @archive.write_report(paths, report)
        report
      end
    end
  end
end
