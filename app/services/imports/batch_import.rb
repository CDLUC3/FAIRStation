module Imports
  # Persists translated records without knowing the external payload format. The caller owns the transaction.
  class BatchImport
    def initialize(batch:, import_run: nil)
      @batch = batch
      if import_run && (batch.source.any? { |key, value| import_run.public_send(key) != value } ||
          batch.stations.none? { |row| row.external_id.to_s == import_run.station_external_id })
        raise Error, "Import receipt does not match the batch source and station"
      end
      @records = SourceIdentityMap.new(source: batch.source, import_run: import_run)
      @people = PersonIdentity.new(identities: @records, people: batch.people)
    end

    def call
      @batch.stations.each { |row| import_station(row) }
      @batch.people.each { |row| import_person(row) }
      @batch.activities.each { |row| import_activity(row) }
      import_memberships
      # Read persisted values back in batches for validation.
      SourceIdentityMap.new(source: @batch.source)
    end

    private

    def import_station(row)
      # Existing station metadata is curated and is preserved across imports.
      station = @records.find(Station, row.external_id) || Station.create!(row.attributes)
      @records.identify(station, row.external_id)
    end

    def import_person(row)
      existing = @people.resolve(row)
      attributes = { name: row.attributes.fetch(:name), orcid: Person.normalize_value_for(:orcid, row.attributes.fetch(:orcid)) || existing&.orcid }
      person = persist(Person, existing, attributes)
      @records.identify(person, row.external_id)
      @people.remember(person)
    end

    def import_activity(row)
      stations = row.station_ids.map { |id| @records.fetch(Station, id) }
      existing = @records.find(ResearchActivity, row.external_id)
      activity = if existing
        refresh_activity(existing, row.attributes, stations)
      else
        ResearchActivity.create!(**row.attributes, stations: stations)
      end
      @records.identify(activity, row.external_id)
    end

    def refresh_activity(activity, attributes, stations)
      activity.update!(attributes)
      stations.each { |station| activity.stations << station unless activity.stations.include?(station) }
      activity
    end

    def import_memberships
      activities = @batch.activities.map { |row| @records.fetch(ResearchActivity, row.external_id).id }
      memberships = ActivityPerson.where(research_activity_id: activities).index_by { |membership| [ membership.research_activity_id, membership.person_id ] }
      incoming = @batch.memberships.group_by { |row| membership_key(row) }
      incoming.each { |key, rows| import_membership(rows, memberships[key]) }
    end

    def membership_key(row)
      [ @records.fetch(ResearchActivity, row.activity_id).id,
        @records.fetch(Person, row.person_id).id ]
    end

    def import_membership(rows, existing)
      attributes = rows.map(&:attributes).uniq
      raise Error, "Conflicting incoming memberships for activity #{rows.first.activity_id}" unless attributes.one?
      activity_id, person_id = membership_key(rows.first)
      rows.each { |row| verify_membership_identity!(row, activity_id, person_id) }
      membership = persist(ActivityPerson, existing, attributes.sole.merge(research_activity_id: activity_id, person_id: person_id))
      rows.each { |row| @records.identify(membership, row.external_id) }
    end

    def verify_membership_identity!(row, activity_id, person_id)
      existing = @records.find(ActivityPerson, row.external_id)
      if existing && [ existing.research_activity_id, existing.person_id ] != [ activity_id, person_id ]
        raise Error, "Membership identity conflict for #{row.external_id}"
      end
    end

    def persist(type, existing, attributes)
      return type.create!(attributes) unless existing
      existing.update!(attributes) if attributes.any? { |field, value| existing.public_send(field) != value }
      existing
    end
  end
end
