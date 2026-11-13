module Rams
  # Evidence and field accounting for the model-validation run, not an output model.
  class ValidationReport
    def initialize(snapshot:, today:)
      @snapshot, @today = snapshot, today
      @retrieved_at = Time.current.iso8601
      @checks = []
      @station_differences = {}
    end

    def validate!(client:, station:)
      @snapshot.fetch("reserves").fetch("data").sole.slice(*QuailRidgeSync::STATION_FIELDS).each do |field, value|
        local = station.attributes.fetch(field).as_json
        @station_differences[field] = { source: value, stored: local } unless equivalent?(local, value)
      end
      projects = @snapshot.fetch("projects").fetch("data")
      current = projects.select { |row| current?(row) }
      historical = projects.select { |row| historical?(row) }
      { "current" => current.first(3), "historical" => historical.last(5) }.each do |group, rows|
        rows.each do |row|
          live = client.record("projects", row.fetch("id"))
          raise Error, "Project #{row['id']} changed during pull; rerun" unless live == row
          activity = identifier(ResearchActivity, row.fetch("id")).record.reload
          fields = row.to_h do |field, value|
            target = QuailRidgeSync::PROJECT_FIELDS[field]
            stored = target ? activity.attributes.fetch(target).as_json : nil
            result = if target
              raise Error, "Project #{row['id']}: mismatch in #{field}" unless equivalent?(stored, value)
              { disposition: "mapped to #{target}", source: value, stored: stored, matches: true }
            elsif field == "id"
              { disposition: "SourceIdentifier (ResearchActivity)", matches: identifier(ResearchActivity, value).record == activity }
            elsif field == "reserve"
              raise Error, "Project station link mismatch" unless activity.stations.include?(station)
              { disposition: "ActivityStation; reserve labels not copied", matches: true }
            elsif %w[owner applicant].include?(field)
              person = identifier(Person, value.fetch("id")).record if value
              { disposition: "Person + SourceIdentifier; owner/applicant relationship not modeled",
                matches: value.nil? || person.present?, fields: person_fields(person, value) }
            else
              { disposition: "not imported", source: value }
            end
            [ field, result ]
          end
          raise Error, "Project identity mismatch" if fields.values.any? { |check| check[:matches] == false }
          @checks << { group: group, project_id: row.fetch("id"), fields: fields }
        end
      end
      @sample_shortfall = { current: [ 3 - current.size, 0 ].max, historical: [ 5 - historical.size, 0 ].max }
    end

    def as_json
      {
        source: Client::BASE_URL, source_instance: "ucnature", reserve_id: QuailRidgeSync::RESERVE_ID,
        retrieved_at: @retrieved_at, current_definition: "status=open and end_date absent or >= #{@today}",
        historical_definition: "status=closed or end_date before #{@today}",
        unmodeled_relationships: %w[owner applicant].index_with { |field| @snapshot.fetch("projects").fetch("data").count { |row| row[field] } },
        counts: @snapshot.transform_values { |rows| { pulled: rows.fetch("data").size, rams: rows.fetch("total_count") } },
        imported: imported_counts,
        station_differences_preserved: @station_differences,
        dropped_fields: dropped_fields,
        visits_with_projects_outside_pull: outside_project_visits,
        spot_checks: @checks, sample_shortfall: @sample_shortfall,
        snapshot: @snapshot
      }
    end

    private

    def identifier(type, id)
      SourceIdentifier.find_by!(**QuailRidgeSync::SOURCE, record_type: type.name, external_id: id.to_s)
    end

    def person_fields(person, source)
      return {} unless source
      {
        "full_name" => { source: source.fetch("full_name"), stored: person.name, matches: source.fetch("full_name") == person.name },
        "orcid" => { source: source.fetch("orcid"), stored: person.orcid, matches: Person.new(orcid: source.fetch("orcid")).orcid == person.orcid }
      }
    end

    def imported_counts
      [ Station, ResearchActivity, Person, ActivityPerson ].to_h do |type|
        [ type.name, SourceIdentifier.where(**QuailRidgeSync::SOURCE, record_type: type.name).distinct.count(:record_id) ]
      end
    end

    def current?(row)
      row.fetch("status") == "open" && (row["end_date"].blank? || Date.iso8601(row.fetch("end_date")) >= @today)
    end

    def historical?(row)
      row.fetch("status") == "closed" || (row["end_date"].present? && Date.iso8601(row.fetch("end_date")) < @today)
    end

    def equivalent?(stored, source)
      return stored == source if stored.nil? || source.nil?
      if stored.is_a?(String) && source.is_a?(String) && source.match?(/\A\d{4}-\d{2}-\d{2}T/)
        return Time.iso8601(stored) == Time.iso8601(source)
      end
      return stored.to_f == source.to_f if stored.is_a?(Numeric) || source.is_a?(Numeric)
      stored == source
    end

    def outside_project_visits
      ids = @snapshot.fetch("projects").fetch("data").map { |row| row.fetch("id") }
      @snapshot.fetch("visits").fetch("data").filter_map do |row|
        project_id = row.dig("project", "id")
        { visit_id: row.fetch("id"), project_id: project_id } if project_id && !ids.include?(project_id)
      end
    end

    def dropped_fields
      @snapshot.to_h do |resource, rows|
        counts = Hash.new { |hash, key| hash[key] = { present: 0, nonblank: 0 } }
        rows.fetch("data").each do |row|
          leaves(row).each do |path, value|
            next if imported_path?(resource, path)
            counts[path][:present] += 1
            counts[path][:nonblank] += 1 if value == false || value.present?
          end
        end
        [ resource, counts.sort.to_h ]
      end
    end

    def leaves(value, prefix = nil)
      if value.is_a?(Hash) && value.any?
        value.flat_map { |key, child| leaves(child, [ prefix, key ].compact.join(".")) }
      elsif value.is_a?(Array) && value.any?
        value.flat_map { |child| leaves(child, "#{prefix}[]") }
      else
        [ [ prefix, value ] ]
      end
    end

    def imported_path?(resource, path)
      case resource
      when "reserves"
        # Existing station directory values are preserved, not refreshed from RAMS.
        path == "id"
      when "projects"
        path == "id" || path == "reserve.id" || QuailRidgeSync::PROJECT_FIELDS.key?(path) ||
          path.match?(/\A(owner|applicant)\.(id|full_name|orcid)\z/)
      when "team_memberships"
        %w[id project.id user.id user.full_name user.orcid user_role active is_principal_investigator].include?(path)
      else
        false
      end
    end
  end
end
