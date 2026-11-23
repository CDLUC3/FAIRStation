module Rams
  class SnapshotPull
    def initialize(client:, adapter:)
      @client, @adapter = client, adapter
    end

    def collections
      reserves = pull_reserves
      visits = pull_visits
      projects = pull_projects(visits)
      { "reserves" => reserves, "projects" => { "data" => projects, "total_count" => projects.size },
        "team_memberships" => @client.collection("team_memberships"),
        "visits" => visits,
        "fundings" => @client.collection("fundings", reserve_id: @adapter.reserve_id),
        "institutions" => @client.collection("institutions") }
    end

    private

    def pull_reserves
      @client.collection("reserves").tap { |reserves| verify_reserve!(reserves.fetch("data")) }
    end

    def verify_reserve!(reserves)
      unless reserves.one? { |row| row.fetch("id") == @adapter.reserve_id }
        raise Error, "Selected reserve #{@adapter.reserve_id} is not visible in the RAMS directory; stopped"
      end
    end

    def pull_visits
      reserve_id = @adapter.reserve_id
      visits = @client.collection("visits", reserve_id: reserve_id)
      visits.fetch("data").each do |row|
        raise Error, "Out-of-scope visits record #{row['id']}" unless row.dig("reserve", "id") == reserve_id
      end
      visits
    end

    def pull_projects(visits)
      ids = visits.fetch("data").map { |row| row.fetch("project").fetch("id") }.uniq
      ids.map do |id|
        @client.record("projects", id).tap do |row|
          raise Error, "RAMS returned the wrong project for #{id}" unless row.fetch("id") == id
        end
      end
    end
  end
end
