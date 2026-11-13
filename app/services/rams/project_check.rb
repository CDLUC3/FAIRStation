module Rams
  # Checks one project against the imported graph; no HTTP or database lookups.
  class ProjectCheck
    def initialize(project:, group:, records:, station:, configuration:)
      @project, @group, @records, @station, @configuration = project, group, records, station, configuration
      @activity = records.fetch(ResearchActivity, project.fetch("id"))
    end

    def to_h
      fields = @project.to_h { |field, value| [ field, check_field(field, value) ] }
      raise Error, "Project #{@project['id']}: imported field mismatch" if fields.values.any? { |check| check[:matches] == false }
      { group: @group, project_id: @project.fetch("id"), fields: fields }
    end

    private

    def check_field(field, value)
      target = @configuration.project_fields[field]
      return mapped_field(target, value) if target
      return source_identity(value) if field == "id"
      return station_link if field == "reserve"
      return person_link(value) if %w[owner applicant].include?(field)
      { disposition: "not imported", source: value }
    end

    def mapped_field(target, value)
      FieldComparison.call(value, @activity.public_send(target).as_json).merge(disposition: "mapped to #{target}")
    end

    def source_identity(id)
      { disposition: "SourceIdentifier (ResearchActivity)", matches: @records.fetch(ResearchActivity, id) == @activity }
    end

    def station_link
      { disposition: "ActivityStation; reserve labels not copied", matches: @activity.stations.include?(@station) }
    end

    def person_link(source)
      person = @records.fetch(Person, source.fetch("id")) if source
      { disposition: "Person + SourceIdentifier; owner/applicant relationship not modeled",
        matches: source.nil? || person.present?, fields: source ? person_fields(person, source) : {} }
    end

    def person_fields(person, source)
      { "full_name" => FieldComparison.call(source.fetch("full_name"), person.name),
        "orcid" => FieldComparison.call(source.fetch("orcid"), person.orcid, expected: Person.normalize_value_for(:orcid, source.fetch("orcid"))) }
    end
  end
end
