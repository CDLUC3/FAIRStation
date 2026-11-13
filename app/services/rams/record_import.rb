module Rams
  # Maps a complete snapshot into domain records. The caller owns the transaction.
  class RecordImport
    def initialize(snapshot:)
      @snapshot = snapshot
      @configuration = snapshot.configuration
      @records = RecordIndex.new(source: @configuration.source, users: snapshot.users)
    end

    def call
      station = import_station
      @snapshot.users.each { |row| import_person(row) }
      @snapshot.rows("projects").each { |row| import_project(row, station) }
      import_memberships
      # Read persisted values back in batches for validation.
      RecordIndex.new(source: @configuration.source)
    end

    private

    def import_station
      row = @snapshot.rows("reserves").sole
      # The seed contains curated coordinates and DOI; refresh neither from RAMS.
      station = @records.find(Station, row.fetch("id")) || Station.create!(row.slice(*@configuration.station_fields))
      @records.identify(station, row.fetch("id"))
    end

    def import_person(row)
      existing = @records.person(row)
      attributes = { name: row.fetch("full_name"), orcid: Person.normalize_value_for(:orcid, row.fetch("orcid")) || existing&.orcid }
      person = persist(Person, existing, attributes)
      @records.identify(person, row.fetch("id"))
    end

    def import_project(row, station)
      existing = @records.find(ResearchActivity, row.fetch("id"))
      attributes = @configuration.project_attributes(row)
      activity = if existing
        existing.update!(attributes)
        existing.stations << station unless existing.stations.include?(station)
        existing
      else
        ResearchActivity.create!(**attributes, stations: [ station ])
      end
      @records.identify(activity, row.fetch("id"))
    end

    def import_memberships
      activities = @snapshot.rows("projects").map { |row| @records.fetch(ResearchActivity, row.fetch("id")).id }
      memberships = ActivityPerson.where(research_activity_id: activities).index_by { |membership| [ membership.research_activity_id, membership.person_id ] }
      incoming = @snapshot.rows("team_memberships").group_by { |row| membership_key(row) }
      incoming.each { |key, rows| import_membership(rows, memberships[key]) }
    end

    def membership_key(row)
      raise Error, "Membership #{row['id']} has no user" unless row["user"]
      [ @records.fetch(ResearchActivity, row.fetch("project").fetch("id")).id,
        @records.fetch(Person, row.fetch("user").fetch("id")).id ]
    end

    def import_membership(rows, existing)
      attributes = rows.map { |row| membership_attributes(row) }.uniq
      raise Error, "Conflicting incoming memberships for project #{rows.first.dig('project', 'id')}" unless attributes.one?
      activity_id, person_id = membership_key(rows.first)
      rows.each { |row| verify_membership_identity!(row, activity_id, person_id) }
      membership = persist(ActivityPerson, existing, attributes.sole.merge(research_activity_id: activity_id, person_id: person_id))
      rows.each { |row| @records.identify(membership, row.fetch("id")) }
    end

    def membership_attributes(row)
      { role: row.fetch("user_role"), active: row.fetch("active"), is_principal_investigator: row.fetch("is_principal_investigator") }
    end

    def verify_membership_identity!(row, activity_id, person_id)
      existing = @records.find(ActivityPerson, row.fetch("id"))
      if existing && [ existing.research_activity_id, existing.person_id ] != [ activity_id, person_id ]
        raise Error, "Membership identity conflict for #{row['id']}"
      end
    end

    def persist(type, existing, attributes)
      return type.create!(attributes) unless existing
      existing.update!(attributes) if attributes.any? { |field, value| existing.public_send(field) != value }
      existing
    end
  end
end
