require "tmpdir"

module Rams
  # Evidence must be durable before the database transaction can commit.
  class EvidenceStore
    def initialize(directory: Rails.root.join("tmp/rams-sync"))
      @directory = directory
    end

    def capture(snapshot)
      FileUtils.mkdir_p(@directory, mode: 0o700)
      directory = Dir.mktmpdir("run-", @directory)
      paths = { snapshot: File.join(directory, "snapshot.json"), report: File.join(directory, "report.json") }
      write_json(paths.fetch(:snapshot), snapshot.collections)
      yield paths
    rescue StandardError
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
      raise
    end

    def write_report(paths, report)
      write_json(paths.fetch(:report), report)
    end

    private

    def write_json(path, value)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(JSON.pretty_generate(value))
        file.flush
        file.fsync
      end
    end
  end
end
