module Imports
  # Per-run identity map: typed source lookups and station links are loaded in batches.
  class SourceIdentityMap
    def initialize(source:)
      @source = source
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
      @identifiers[key(record.class.name, id)] ||= SourceIdentifier.create!(**@source, external_id: id.to_s, record: record)
      record
    end

    def counts
      [ Station, ResearchActivity, Person, ActivityPerson ].to_h do |type|
        records = @identifiers.values.select { |identifier| identifier.record_type == type.name }.map(&:record_id)
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
