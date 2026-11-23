module Rams
  # Collected responses from a scope-checked pull; not an atomic source snapshot.
  class Snapshot
    attr_reader :collections, :adapter, :retrieved_at

    def self.pull(client:, adapter:)
      new(adapter: adapter, collections: SnapshotPull.new(client: client, adapter: adapter).collections)
    end

    def initialize(collections:, adapter:, retrieved_at: Time.current.iso8601)
      @collections, @adapter, @retrieved_at = collections, adapter, retrieved_at
    end

    def rows(resource) = collections.fetch(resource).fetch("data")

    def counts
      collections.transform_values { |collection| { pulled: collection.fetch("data").size, total: collection.fetch("total_count") } }
    end

    def metadata
      { source: adapter.connection.base_url, source_identity: adapter.source,
        reserve_id: adapter.reserve_id, retrieved_at: retrieved_at }
    end

    def reserve = rows("reserves").find { |row| row.fetch("id") == adapter.reserve_id }

    # The endpoint is installation-scoped; import only selected project links.
    def memberships
      rows("team_memberships").select { |row| project_ids.include?(row.fetch("project").fetch("id")) }
    end

    def verify!
      verify_projects!
      verify_visits!
      verify_fundings!
    end

    private

    def project_ids = @project_ids ||= rows("projects").pluck("id").to_set

    def verify_projects!
      visit_projects = rows("visits").map { |row| row.fetch("project").fetch("id") }.to_set
      raise Error, "Visit-linked project selection is incomplete" unless project_ids == visit_projects
    end

    def verify_visits!
      # A visit at this reserve may legitimately reference another reserve's project.
      rows("visits").each { |row| verify_reserve_link!(row, "visits") }
    end

    def verify_fundings!
      rows("fundings").each do |row|
        verify_reserve_link!(row, "fundings")
      end
    end

    def verify_reserve_link!(row, resource)
      raise Error, "Out-of-scope #{resource} record #{row['id']}" unless row.dig("reserve", "id") == adapter.reserve_id
    end
  end
end
