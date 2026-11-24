module Rams
  # Interprets RAMS payloads; the importer sees only FAIR Station records.
  class Adapter
    PROJECT_FIELDS = {
      "title" => :title,
      "abstract" => :description,
      "project_type" => :activity_type,
      "status" => :status,
      "start_date" => :start_date,
      "end_date" => :end_date,
      "discipline" => :discipline,
      "discipline_other" => :discipline_other,
      "keywords" => :keywords,
      "taxonomic_keywords" => :taxonomic_keywords,
      "thesis_title" => :thesis_title,
      "course_title" => :course_title,
      "course_number" => :course_number,
      "submitted_at" => :submitted_at
    }.freeze
    STATION_FIELDS = %w[name short_name description doi latitude longitude].freeze
    attr_reader :connection, :reserve_id

    def initialize(connection:, reserve_id:)
      raise Error, "Expected a RAMS connection" unless connection.adapter == "rams"
      @connection, @reserve_id = connection, Integer(reserve_id)
    end

    def source = connection.source

    def pull(client:)
      Snapshot.pull(client: client, adapter: self).tap(&:verify!)
    end

    def translate(collections:)
      institutions = rows(collections, "institutions").index_by { |row| row.fetch("id") }
      selected_projects = projects(collections)
      selected_memberships = memberships(collections, selected_projects)
      Imports::Batch.new(source: source, stations: [ station(collections) ],
        people: users(selected_projects, selected_memberships).map { |row| person(row) },
        activities: selected_projects.map { |row| activity(row) },
        memberships: selected_memberships.map { |row| membership(row, institutions) })
    end

    private

    def station(collections)
      row = rows(collections, "reserves").find { |candidate| candidate.fetch("id") == reserve_id }
      raise Error, "Selected reserve #{reserve_id} is absent from source data" unless row
      Imports::Batch::StationInput.new(external_id: reserve_id, attributes: row.slice(*STATION_FIELDS).symbolize_keys)
    end

    def rows(collections, resource) = collections.fetch(resource).fetch("data")

    def projects(collections)
      ids = rows(collections, "visits").select { |row| row.dig("reserve", "id") == reserve_id }
        .map { |row| row.fetch("project").fetch("id") }.to_set
      selected = rows(collections, "projects").select { |row| ids.include?(row.fetch("id")) }
      unless selected.pluck("id").to_set == ids
        raise Error, "Visit-linked projects are missing from source data"
      end
      selected
    end

    def memberships(collections, projects)
      project_ids = projects.pluck("id").to_set
      rows(collections, "team_memberships").select { |row| project_ids.include?(row.fetch("project").fetch("id")) }
    end

    def users(projects, memberships)
      membership_users = memberships.filter_map { |row| row["user"] }
      user_ids = membership_users.pluck("id").to_set
      project_users = projects.flat_map { |row| row.values_at("owner", "applicant") }
      assertions = project_users.compact.select { |row| user_ids.include?(row.fetch("id")) } + membership_users
      assertions.group_by { |row| row.fetch("id") }.values.map { |rows| user_assertion(rows) }
    end

    def user_assertion(rows)
      orcids = rows.filter_map { |row| Person.normalize_value_for(:orcid, row.fetch("orcid")) }.uniq
      raise Error, "Inconsistent ORCIDs for RAMS user #{rows.first['id']}" if orcids.many?
      rows.last.merge("orcid" => orcids.first)
    end

    def person(row)
      Imports::Batch::PersonInput.new(external_id: row.fetch("id"),
        attributes: { name: row.fetch("full_name"), orcid: row.fetch("orcid") })
    end

    def activity(row)
      attributes = PROJECT_FIELDS.to_h { |source, target| [ target, row.fetch(source) ] }
      Imports::Batch::ActivityInput.new(external_id: row.fetch("id"), attributes: attributes, station_ids: [ reserve_id ])
    end

    def membership(row, institutions)
      raise Error, "Membership #{row['id']} has no user" unless row["user"]
      Imports::Batch::MembershipInput.new(external_id: row.fetch("id"),
        attributes: membership_attributes(row, institutions),
        activity_id: row.fetch("project").fetch("id"), person_id: row.fetch("user").fetch("id"))
    end

    def membership_attributes(row, institutions)
      institution_id = row.dig("institution", "id")
      { role: row.fetch("user_role"), active: row.fetch("active"),
        is_principal_investigator: row.fetch("is_principal_investigator"),
        affiliation_source_id: institution_id&.to_s,
        affiliation_name: row.dig("institution", "name"),
        affiliation_ror_id: institutions.dig(institution_id, "ror", "ror_id") }
    end
  end
end
