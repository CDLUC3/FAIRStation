module Rams
  # Builds validation evidence from a verified snapshot and the imported graph.
  class ValidationReport
    def initialize(snapshot:, records:, evidence:)
      @snapshot, @records, @evidence = snapshot, records, evidence
      @configuration = snapshot.configuration
      @station = records.fetch(Station, @configuration.reserve_id)
    end

    def to_h
      source_metadata.merge(import_results).merge(validation_results)
    end

    private

    def source_metadata
      { source: @configuration.base_url, source_instance: @configuration.source.fetch(:source_instance),
        reserve_id: @configuration.reserve_id, retrieved_at: @snapshot.retrieved_at,
        current_definition: "status=open and end_date absent or >= #{@snapshot.today}",
        historical_definition: "status=closed or end_date before #{@snapshot.today}",
        snapshot: @snapshot.collections, evidence: @evidence }
    end

    def import_results
      { counts: @snapshot.counts, imported: @records.counts,
        station_differences_preserved: station_differences,
        unmodeled_relationships: unmodeled_relationships,
        dropped_fields: FieldInventory.new(snapshot: @snapshot).to_h,
        visits_with_projects_outside_pull: @snapshot.outside_project_visits }
    end

    def validation_results
      { spot_checks: project_checks, sample_shortfall: @snapshot.sample_shortfall }
    end

    def station_differences
      source = @snapshot.rows("reserves").sole
      @configuration.station_fields.filter_map do |field|
        comparison = FieldComparison.call(source.fetch(field), @station.public_send(field).as_json)
        [ field, comparison.except(:matches) ] unless comparison.fetch(:matches)
      end.to_h
    end

    def unmodeled_relationships
      %w[owner applicant].index_with { |field| @snapshot.rows("projects").count { |row| row[field] } }
    end

    def project_checks
      @snapshot.samples.flat_map do |group, projects|
        projects.map do |project|
          ProjectCheck.new(project: project, group: group, records: @records, station: @station, configuration: @configuration).to_h
        end
      end
    end
  end
end
