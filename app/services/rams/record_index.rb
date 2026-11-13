module Rams
  # Per-run identity map: source lookups and ORCID matches are loaded in batches.
  class RecordIndex
    def initialize(source:, users: [])
      @source = source
      @identifiers = SourceIdentifier.where(source).preload(:record).index_by { |identifier| key(identifier.record_type, identifier.external_id) }
      @people_by_orcid = Person.where(orcid: users.filter_map { |row| normalized_orcid(row) }).index_by(&:orcid)
      preload_stations
    end

    def find(type, id) = @identifiers[key(type.name, id)]&.record

    def fetch(type, id)
      find(type, id) || raise(Error, "Missing #{type.name} for RAMS ID #{id}")
    end

    def person(row)
      sourced = find(Person, row.fetch("id"))
      orcid = normalized_orcid(row)
      matched = @people_by_orcid[orcid] if orcid
      verify_person_identity!(sourced, matched, orcid, row.fetch("id"))
      sourced || matched
    end

    def identify(record, id)
      existing = @identifiers[key(record.class.name, id)]
      raise Error, "Source identity conflict" if existing && existing.record != record
      @identifiers[key(record.class.name, id)] ||= SourceIdentifier.create!(**@source, external_id: id.to_s, record: record)
      @people_by_orcid[record.orcid] = record if record.is_a?(Person) && record.orcid
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

    def normalized_orcid(row) = Person.normalize_value_for(:orcid, row.fetch("orcid"))

    def verify_person_identity!(sourced, matched, orcid, id)
      return unless sourced
      different_person = matched && matched != sourced
      different_orcid = sourced.orcid && orcid && sourced.orcid != orcid
      raise Error, "ORCID identity conflict for RAMS user #{id}" if different_person || different_orcid
    end

    def preload_stations
      activities = @identifiers.values.filter_map { |identifier| identifier.record if identifier.record_type == "ResearchActivity" }
      ActiveRecord::Associations::Preloader.new(records: activities, associations: :stations).call
    end
  end
end
