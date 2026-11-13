module Rams
  # One complete, scope-checked pull. Detail verification finishes before any writes.
  class Snapshot
    attr_reader :collections, :configuration, :retrieved_at, :today

    def self.pull(client:, configuration:, today:)
      reserves = client.collection("reserves")
      verify_reserve!(reserves.fetch("data"), configuration)
      projects = client.collection("projects", reserve_id: configuration.reserve_id)
      raise Error, "RAMS production has no Quail Ridge projects; stopped" if projects.fetch("data").empty?

      new(configuration: configuration, today: today, collections: {
        "reserves" => reserves, "projects" => projects,
        "team_memberships" => client.collection("team_memberships"),
        "visits" => client.collection("visits", reserve_id: configuration.reserve_id),
        "fundings" => client.collection("fundings", reserve_id: configuration.reserve_id),
        "institutions" => client.collection("institutions")
      })
    end

    def self.verify_reserve!(reserves, configuration)
      unless reserves.size == 1 && reserves.first.fetch("id") == configuration.reserve_id && reserves.first.fetch("name") == configuration.reserve_name
        raise Error, "Expected a token scoped only to #{configuration.reserve_name}; stopped"
      end
    end

    def initialize(collections:, configuration:, today:, retrieved_at: Time.current.iso8601)
      @collections, @configuration, @today, @retrieved_at = collections, configuration, today, retrieved_at
    end

    def rows(resource) = collections.fetch(resource).fetch("data")

    def counts
      collections.transform_values { |collection| { pulled: collection.fetch("data").size, rams: collection.fetch("total_count") } }
    end

    def users
      project_users = rows("projects").flat_map { |row| row.values_at("owner", "applicant") }
      assertions = (project_users + rows("team_memberships").map { |row| row["user"] }).compact
      assertions.group_by { |row| row.fetch("id") }.values.map { |rows| user_assertion(rows) }
    end

    def samples
      { "current" => rows("projects").select { |row| current?(row) }.first(3),
        "historical" => rows("projects").select { |row| historical?(row) }.last(5) }
    end

    def sample_shortfall
      { current: 3 - samples.fetch("current").size, historical: 5 - samples.fetch("historical").size }
    end

    def verify!(client:)
      verify_projects!
      verify_memberships!
      verify_visits!
      verify_fundings!
      samples.values.flatten.each do |row|
        raise Error, "Project #{row['id']} changed during pull; rerun" unless client.record("projects", row.fetch("id")) == row
      end
    end

    def outside_project_visits
      rows("visits").filter_map do |row|
        project_id = row.dig("project", "id")
        { visit_id: row.fetch("id"), project_id: project_id } if project_id && !project_ids.include?(project_id)
      end
    end

    private

    def user_assertion(rows)
      orcids = rows.filter_map { |row| Person.normalize_value_for(:orcid, row.fetch("orcid")) }.uniq
      raise Error, "Inconsistent ORCIDs for RAMS user #{rows.first['id']}" if orcids.many?
      rows.last.merge("orcid" => orcids.first)
    end

    def project_ids = @project_ids ||= rows("projects").pluck("id").to_set

    def verify_projects!
      rows("projects").each { |row| verify_reserve_link!(row, "projects") }
    end

    def verify_memberships!
      rows("team_memberships").each { |row| verify_project_link!(row, "team_memberships") }
    end

    def verify_visits!
      # A visit at this reserve may legitimately reference another reserve's project.
      rows("visits").each { |row| verify_reserve_link!(row, "visits") }
    end

    def verify_fundings!
      rows("fundings").each do |row|
        verify_project_link!(row, "fundings")
        verify_reserve_link!(row, "fundings")
      end
    end

    def verify_reserve_link!(row, resource)
      raise Error, "Out-of-scope #{resource} record #{row['id']}" unless row.dig("reserve", "id") == configuration.reserve_id
    end

    def verify_project_link!(row, resource)
      raise Error, "Out-of-scope #{resource} record #{row['id']}" unless project_ids.include?(row.dig("project", "id"))
    end

    def current?(row)
      row.fetch("status") == "open" && (row["end_date"].blank? || Date.iso8601(row.fetch("end_date")) >= today)
    end

    def historical?(row)
      row.fetch("status") == "closed" || (row["end_date"].present? && Date.iso8601(row.fetch("end_date")) < today)
    end
  end
end
