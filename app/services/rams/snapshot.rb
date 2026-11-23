module Rams
  # Collected responses from a scope-checked pull; not an atomic source snapshot.
  class Snapshot
    attr_reader :collections, :adapter, :retrieved_at

    def self.pull(client:, adapter:)
      reserves = client.collection("reserves")
      verify_reserve!(reserves.fetch("data"), adapter)
      visits = pull_visits(client, adapter.reserve_id)
      projects = pull_projects(client, visits)
      new(adapter: adapter, collections: pull_collections(client, adapter.reserve_id, reserves, visits, projects))
    end

    def self.pull_visits(client, reserve_id)
      visits = client.collection("visits", reserve_id: reserve_id)
      visits.fetch("data").each do |row|
        raise Error, "Out-of-scope visits record #{row['id']}" unless row.dig("reserve", "id") == reserve_id
      end
      visits
    end

    def self.pull_projects(client, visits)
      ids = visits.fetch("data").map { |row| row.fetch("project").fetch("id") }.uniq
      ids.map do |id|
        client.record("projects", id).tap do |row|
          raise Error, "RAMS returned the wrong project for #{id}" unless row.fetch("id") == id
        end
      end
    end

    def self.pull_collections(client, reserve_id, reserves, visits, projects)
      {
        "reserves" => reserves, "projects" => { "data" => projects, "total_count" => projects.size },
        "team_memberships" => client.collection("team_memberships"),
        "visits" => visits,
        "fundings" => client.collection("fundings", reserve_id: reserve_id),
        "institutions" => client.collection("institutions")
      }
    end
    private_class_method :pull_visits, :pull_projects, :pull_collections

    def self.verify_reserve!(reserves, adapter)
      unless reserves.one? { |row| row.fetch("id") == adapter.reserve_id }
        raise Error, "Selected reserve #{adapter.reserve_id} is not visible in the RAMS directory; stopped"
      end
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
