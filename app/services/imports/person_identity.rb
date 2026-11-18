module Imports
  # Source IDs establish identity. An asserted ORCID can flag a conflict,
  # but cannot authorize linking another source identity to an existing person.
  class PersonIdentity
    def initialize(identities:, people:)
      @identities = identities
      @people_by_orcid = Person.where(orcid: people.filter_map { |row| normalized_orcid(row) }).index_by(&:orcid)
    end

    def resolve(row)
      sourced = @identities.find(Person, row.external_id)
      orcid = normalized_orcid(row)
      matched = @people_by_orcid[orcid] if orcid
      if (matched && matched != sourced) || (sourced&.orcid && orcid && sourced.orcid != orcid)
        raise Error, "ORCID identity conflict for source person #{row.external_id}"
      end
      sourced
    end

    def remember(person)
      @people_by_orcid[person.orcid] = person if person.orcid
    end

    private

    def normalized_orcid(row) = Person.normalize_value_for(:orcid, row.attributes.fetch(:orcid))
  end
end
