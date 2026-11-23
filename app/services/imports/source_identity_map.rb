module Imports
  # Per-run identity map: typed source lookups and station links are loaded in batches.
  class SourceIdentityMap
    def initialize(source:, import_run: nil)
      @source, @import_run = source, import_run
      @identifiers = SourceIdentifier.where(source).preload(:record).index_by { |identifier| key(identifier.record_type, identifier.external_id) }
      preload_stations
    end

    def find(type, id) = @identifiers[key(type.name, id)]&.record

    def fetch(type, id)
      find(type, id) || raise(Error, "Missing #{type.name} for source ID #{id}")
    end

    def identify(record, id)
      existing = @identifiers[key(record.class.name, id)]
      raise Error, "Source identity conflict" if existing && existing.record != record
      identifier = @identifiers[key(record.class.name, id)] ||= SourceIdentifier.create!(**@source, external_id: id.to_s, record: record)
      identifier.update_columns(import_run_id: @import_run.id, updated_at: Time.current) if @import_run && identifier.import_run_id != @import_run.id
      record
    end

    def counts(batch:)
      { Station => batch.stations, ResearchActivity => batch.activities,
        Person => batch.people, ActivityPerson => batch.memberships + batch.assignments }.to_h do |type, rows|
        records = rows.map { |row| fetch(type, row.external_id).id }
        [ type.name, records.uniq.size ]
      end
    end

    private

    def key(type, id) = [ type, id.to_s ]

    def preload_stations
      activities = @identifiers.values.filter_map { |identifier| identifier.record if identifier.record_type == "ResearchActivity" }
      ActiveRecord::Associations::Preloader.new(records: activities, associations: :stations).call
    end
  end
end
