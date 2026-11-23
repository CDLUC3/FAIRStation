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
      @batch.assignments.each { |row| import_assignment(row) }
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
      attributes = row.attributes
      activity = if existing
        existing.update!(attributes)
        stations.each { |station| existing.stations << station unless existing.stations.include?(station) }
        existing
      else
        ResearchActivity.create!(**attributes, stations: stations)
      end
      @records.identify(activity, row.external_id)
    end

    def import_memberships
      activities = @batch.activities.map { |row| @records.fetch(ResearchActivity, row.external_id).id }
      links = ActivityPerson.where(research_activity_id: activities)
        .index_by { |link| [ link.research_activity_id, link.person_id, link.role ] }
      incoming = @batch.memberships.group_by { |row| activity_person_key(row) }
      incoming.each { |key, rows| import_membership(rows, key, links) }
    end

    def activity_person_key(row)
      [ @records.fetch(ResearchActivity, row.activity_id).id,
        @records.fetch(Person, row.person_id).id ]
    end

    def import_membership(rows, key, links)
      attributes = rows.map(&:attributes).uniq
      raise Error, "Conflicting incoming memberships for activity #{rows.first.activity_id}" unless attributes.one?
      activity_id, person_id = key
      identified = rows.filter_map { |row| @records.find(ActivityPerson, row.external_id) }.uniq
      if identified.many? || identified.any? { |link| [ link.research_activity_id, link.person_id ] != key }
        raise Error, "Membership identity conflict for activity #{rows.first.activity_id}"
      end
      existing = identified.first || links[[ *key, attributes.sole[:role] ]]
      membership = persist(ActivityPerson, existing, attributes.sole.merge(research_activity_id: activity_id, person_id: person_id))
      rows.each { |row| @records.identify(membership, row.external_id) }
    end

    def import_assignment(row)
      activity_id, person_id = activity_person_key(row)
      existing = @records.find(ActivityPerson, row.external_id)
      if existing && [ existing.research_activity_id, existing.role ] != [ activity_id, row.role ]
        raise Error, "Assignment identity conflict for #{row.external_id}"
      end
      link = persist(ActivityPerson, existing, research_activity_id: activity_id, person_id: person_id, role: row.role)
      @records.identify(link, row.external_id)
    end

    def persist(type, existing, attributes)
      return type.create!(attributes) unless existing
      existing.update!(attributes) if attributes.any? { |field, value| existing.public_send(field) != value }
      existing
    end
  end
end
