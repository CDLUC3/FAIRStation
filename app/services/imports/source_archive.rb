require "tmpdir"

module Imports
  # Stores the retrieved source data and metadata before database writes.
  class SourceArchive
    def initialize(directory: Rails.root.join("tmp/source-imports"))
      @directory = directory
    end

    def capture(snapshot)
      FileUtils.mkdir_p(@directory, mode: 0o700)
      directory = Dir.mktmpdir("run-", @directory)
      yield write_snapshot(directory, snapshot)
    rescue StandardError
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
      raise
    end

    private

    def write_snapshot(directory, snapshot)
      paths = { snapshot: File.join(directory, "snapshot.json"), metadata: File.join(directory, "retrieval.json") }
      write_json(paths.fetch(:snapshot), snapshot.collections)
      write_json(paths.fetch(:metadata), snapshot.metadata)
      paths
    end

    def write_json(path, value)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(JSON.pretty_generate(value))
        file.flush
        file.fsync
      end
    end
  end
end
