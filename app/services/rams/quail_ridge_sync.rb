module Rams
  # Full snapshot import for the first model-validation run, invoked by rake.
  class QuailRidgeSync
    RESERVE_ID = 27
    SOURCE = { source_system: "rams", source_instance: "ucnature" }.freeze
    PROJECT_FIELDS = {
      "title" => "title", "abstract" => "description", "project_type" => "activity_type",
      "status" => "status", "start_date" => "start_date", "end_date" => "end_date",
      "discipline" => "discipline", "discipline_other" => "discipline_other",
      "keywords" => "keywords", "taxonomic_keywords" => "taxonomic_keywords",
      "thesis_title" => "thesis_title", "course_title" => "course_title",
      "course_number" => "course_number", "submitted_at" => "submitted_at"
    }.freeze
    STATION_FIELDS = %w[name short_name description doi latitude longitude].freeze

    def initialize(client:, output: $stdout, today: Date.current)
      @client, @output, @today = client, output, today
    end

    def call
      snapshot = pull
      report = ValidationReport.new(snapshot: snapshot, today: @today)
      ApplicationRecord.transaction do
        station = import_station(snapshot.fetch("reserves").fetch("data").sole)
        snapshot.fetch("projects").fetch("data").each { |row| import_project(row, station) }
        snapshot.fetch("team_memberships").fetch("data").each { |row| import_membership(row) }
        report.validate!(client: @client, station: station)
      end
      report.as_json
    end

    private

    def pull
      snapshot = { "reserves" => @client.collection("reserves") }
      reserves = snapshot.fetch("reserves").fetch("data")
      unless reserves.size == 1 && reserves.first.fetch("id") == RESERVE_ID && reserves.first.fetch("name") == "Quail Ridge Reserve"
        raise Error, "Expected a token scoped only to Quail Ridge (reserve 27); stopped"
      end
      snapshot["projects"] = @client.collection("projects", reserve_id: RESERVE_ID)
      raise Error, "RAMS production has no Quail Ridge projects; stopped" if snapshot["projects"]["data"].empty?
      snapshot["team_memberships"] = @client.collection("team_memberships")
      snapshot["visits"] = @client.collection("visits", reserve_id: RESERVE_ID)
      snapshot["fundings"] = @client.collection("fundings", reserve_id: RESERVE_ID)
      snapshot["institutions"] = @client.collection("institutions")
      verify_scope!(snapshot)
      snapshot.each { |resource, rows| @output.puts "#{resource}: pulled #{rows['data'].size} / RAMS #{rows['total_count']}" }
      snapshot
    end

    def verify_scope!(snapshot)
      projects = snapshot.fetch("projects").fetch("data")
      project_ids = projects.map { |row| row.fetch("id") }
      projects.each do |row|
        raise Error, "Out-of-reserve project #{row['id']}" unless row.dig("reserve", "id") == RESERVE_ID
      end
      %w[team_memberships visits fundings].each do |resource|
        snapshot.fetch(resource).fetch("data").each do |row|
          project_id = row.dig("project", "id")
          # Visits are scoped by their own reserve and may reference another reserve's project.
          valid_project = resource == "visits" || project_ids.include?(project_id)
          valid_reserve = resource == "team_memberships" || row.dig("reserve", "id") == RESERVE_ID
          raise Error, "Out-of-scope #{resource} record #{row['id']}" unless valid_project && valid_reserve
        end
      end
    end

    def import_station(row)
      station = lookup(Station, row.fetch("id")) || Station.new
      # Preserve curated seed data (including the corrected west longitude).
      STATION_FIELDS.each { |field| station[field] = row.fetch(field) } if station.new_record?
      station.save!
      identify(station, row.fetch("id"))
      station
    end

    def import_project(row, station)
      activity = lookup(ResearchActivity, row.fetch("id")) || ResearchActivity.new
      activity.assign_attributes(PROJECT_FIELDS.to_h { |source, target| [ target, row.fetch(source) ] })
      activity.stations << station unless activity.stations.include?(station)
      activity.save!
      identify(activity, row.fetch("id"))
      %w[owner applicant].each { |field| import_person(row[field]) if row[field] }
    end

    def import_membership(row)
      activity = lookup(ResearchActivity, row.fetch("project").fetch("id"))
      raise Error, "Membership #{row['id']} has no user" unless row["user"]
      person = import_person(row.fetch("user"))
      membership = lookup(ActivityPerson, row.fetch("id")) || activity.activity_people.find_or_initialize_by(person: person)
      unless membership.person == person && membership.research_activity == activity
        raise Error, "Membership identity conflict for #{row['id']}"
      end
      attributes = { role: row.fetch("user_role"), active: row.fetch("active"), is_principal_investigator: row.fetch("is_principal_investigator") }
      # Multiple RAMS users can share an ORCID. Do not silently overwrite conflicting roles.
      other_ids = membership.source_identifiers.where(SOURCE).where.not(external_id: row.fetch("id").to_s)
      if other_ids.exists? && attributes.any? { |key, value| membership[key] != value }
        raise Error, "Conflicting memberships for one ORCID in project #{row.dig('project', 'id')}"
      end
      membership.update!(attributes)
      identify(membership, row.fetch("id"))
    end

    def import_person(row)
      orcid = Person.new(orcid: row.fetch("orcid")).orcid
      sourced = lookup(Person, row.fetch("id"))
      matched = Person.find_by(orcid: orcid) if orcid
      if sourced && ((matched && matched != sourced) || (sourced.orcid && orcid && sourced.orcid != orcid))
        raise Error, "ORCID identity conflict for RAMS user #{row['id']}"
      end
      person = sourced || matched || Person.new
      person.name = row.fetch("full_name")
      person.orcid = orcid if orcid
      person.save!
      identify(person, row.fetch("id"))
      person
    end

    def lookup(type, id)
      SourceIdentifier.find_by(**SOURCE, record_type: type.name, external_id: id.to_s)&.record
    end

    def identify(record, id)
      identifier = SourceIdentifier.find_or_initialize_by(**SOURCE, record_type: record.class.name, external_id: id.to_s)
      raise Error, "Source identity conflict" if identifier.persisted? && identifier.record != record
      identifier.update!(record: record)
    end
  end
end
