module Rams
  # Non-secret source settings and the external-to-local field crosswalk.
  Configuration = Data.define(:base_url, :reserve_id, :reserve_name, :source, :project_fields, :station_fields, :imported_paths) do
    def self.load
      values = Rails.application.config_for(:rams).to_h
      new(**values.merge(project_fields: values.fetch(:project_fields).stringify_keys))
    end

    def project_attributes(row)
      project_fields.to_h { |source, target| [ target, row.fetch(source) ] }
    end

    def imported_path?(resource, path)
      imported_paths.fetch(resource.to_sym, []).include?(path) ||
        (resource == "projects" && project_fields.key?(path))
    end
  end
end
