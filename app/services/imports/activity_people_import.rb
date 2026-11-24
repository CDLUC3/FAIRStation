module Imports
  # Reconciles membership and assignment assertions against the same set of role links.
  class ActivityPeopleImport
    def initialize(batch:, records:)
      @batch = batch
      @records = records
      activity_ids = batch.activities.map { |row| records.fetch(ResearchActivity, row.external_id).id }
      @links = ActivityPerson.where(research_activity_id: activity_ids).index_by { |link| link_key(link) }
    end

    def call
      memberships = @batch.memberships.group_by { |row| activity_person_key(row) }
      memberships.each { |key, rows| import_memberships(key, rows) }
      @batch.assignments.each { |row| import_assignment(row) }
    end

    private

    def activity_person_key(row)
      [ @records.fetch(ResearchActivity, row.activity_id).id, @records.fetch(Person, row.person_id).id ]
    end

    def link_key(link) = [ link.research_activity_id, link.person_id, link.role ]

    def import_memberships(key, rows)
      attributes = rows.map(&:attributes).uniq
      raise Error, "Conflicting incoming memberships for activity #{rows.first.activity_id}" unless attributes.one?
      ids = rows.map(&:external_id)
      existing = identified_membership(ids, key, rows.first.activity_id)
      persist_link(existing, ids, key, attributes.sole)
    end

    def identified_membership(ids, key, activity_external_id)
      identified = ids.filter_map { |id| @records.find(ActivityPerson, id) }.uniq
      if identified.many? || identified.any? { |link| [ link.research_activity_id, link.person_id ] != key }
        raise Error, "Membership identity conflict for activity #{activity_external_id}"
      end
      identified.first
    end

    def import_assignment(row)
      key = activity_person_key(row)
      existing = @records.find(ActivityPerson, row.external_id)
      if existing && [ existing.research_activity_id, existing.role ] != [ key.first, row.role ]
        raise Error, "Assignment identity conflict for #{row.external_id}"
      end
      persist_link(existing, [ row.external_id ], key, { role: row.role })
    end

    def persist_link(existing, ids, person_key, attributes)
      key = [ *person_key, attributes.fetch(:role) { existing&.role } ]
      link = link_to_update(existing, key, ids)
      link.assign_attributes(attributes.merge(research_activity_id: key[0], person_id: key[1]))
      link.save! if link.new_record? || link.has_changes_to_save?
      move_identities(existing, link, ids) if existing && existing != link
      ids.each { |id| @records.identify(link, id) }
      @links[key] = link
    end

    def link_to_update(existing, key, ids)
      return existing if existing && link_key(existing) == key
      return @links[key] if @links.key?(key)
      return ActivityPerson.new if !existing || other_identities?(existing, ids)

      @links.delete(link_key(existing))
      existing
    end

    def move_identities(existing, link, ids)
      moved = ids.select { |id| @records.find(ActivityPerson, id) == existing }
      @records.move_activity_person_identities(from: existing, to: link, external_ids: moved)
      return if existing.source_identifiers.exists?

      @links.delete(link_key(existing))
      existing.destroy!
    end

    def other_identities?(link, ids)
      own_source = @batch.source.merge(external_id: ids.map(&:to_s))
      link.source_identifiers.where.not(own_source).exists?
    end
  end
end
