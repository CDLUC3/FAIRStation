module Rams
  # Diagnostic results for one retrieval compared with existing imported data.
  class ValidationReport
    def initialize(snapshot:, records:, samples:, evidence:)
      @snapshot, @records, @samples, @evidence = snapshot, records, samples, evidence
    end

    def to_h
      source_metadata.merge(import_results).merge(validation_results)
    end

    private

    def source_metadata
      @snapshot.metadata.merge(
        current_definition: "status=open and end_date absent or >= #{@samples.today}",
        historical_definition: "status=closed or end_date before #{@samples.today}",
        evidence: @evidence)
    end

    def import_results
      { counts: @snapshot.counts, imported: @records.counts,
        station_differences_preserved: station_differences,
        memberships_outside_selection: @snapshot.rows("team_memberships").size - @snapshot.memberships.size,
        unmodeled_relationships: unmodeled_relationships,
        dropped_fields: FieldInventory.new(snapshot: @snapshot).to_h,
        visits_with_projects_outside_pull: outside_project_visits }
    end

    def validation_results
      { spot_checks: project_checks, sample_shortfall: @samples.shortfall }
    end

    def station = @records.fetch(Station, @snapshot.adapter.reserve_id)

    def outside_project_visits
      project_ids = @snapshot.rows("projects").pluck("id").to_set
      @snapshot.rows("visits").filter_map do |row|
        id = row.dig("project", "id")
        { visit_id: row.fetch("id"), project_id: id } if id && !project_ids.include?(id)
      end
    end

    def station_differences
      source = @snapshot.reserve
      Adapter::STATION_FIELDS.filter_map do |field|
        comparison = FieldComparison.call(source.fetch(field), station.public_send(field).as_json)
        [ field, comparison.except(:matches) ] unless comparison.fetch(:matches)
      end.to_h
    end

    def unmodeled_relationships
      %w[owner applicant].index_with { |field| @snapshot.rows("projects").count { |row| row[field] } }
    end

    def project_checks
      @samples.groups.flat_map do |group, projects|
        projects.map do |project|
          ProjectCheck.new(project: project, group: group, records: @records, station: station).to_h
        end
      end
    end
  end
end
