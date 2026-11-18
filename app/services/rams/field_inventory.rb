module Rams
  # Reports unmapped nested JSON values; not validation of research assertions.
  class FieldInventory
    IMPORTED_PATHS = {
      "reserves" => %w[id],
      "projects" => %w[id reserve.id owner.id owner.full_name owner.orcid applicant.id applicant.full_name applicant.orcid],
      "team_memberships" => %w[id project.id user.id user.full_name user.orcid user_role active is_principal_investigator]
    }.freeze

    def initialize(snapshot:)
      @snapshot = snapshot
    end

    def to_h
      @snapshot.collections.keys.index_with { |resource| counts(resource) }
    end

    private

    def counts(resource)
      imported = imported_rows(resource).to_set
      dropped = @snapshot.rows(resource).flat_map do |row|
        leaves(row).reject { |path, _| imported.include?(row) && imported_path?(resource, path) }
      end
      dropped.group_by(&:first).sort.to_h.transform_values do |entries|
        { present: entries.size, nonblank: entries.count { |_, value| value == false || value.present? } }
      end
    end

    def imported_rows(resource)
      case resource
      when "reserves" then [ @snapshot.reserve ]
      when "team_memberships" then @snapshot.memberships
      else @snapshot.rows(resource)
      end
    end

    def imported_path?(resource, path)
      IMPORTED_PATHS.fetch(resource, []).include?(path) ||
        (resource == "projects" && Adapter::PROJECT_FIELDS.key?(path))
    end

    def leaves(value, prefix = nil)
      return [ [ prefix, value ] ] if value.blank?
      case value
      when Hash
        value.flat_map { |key, child| leaves(child, [ prefix, key ].compact.join(".")) }
      when Array
        value.flat_map { |child| leaves(child, "#{prefix}[]") }
      else
        [ [ prefix, value ] ]
      end
    end
  end
end
