module Rams
  # Accounts for every unsupported leaf, including new fields in future payloads.
  class FieldInventory
    def initialize(snapshot:)
      @snapshot = snapshot
    end

    def to_h
      @snapshot.collections.keys.index_with { |resource| counts(resource) }
    end

    private

    def counts(resource)
      fields = @snapshot.rows(resource).flat_map { |row| leaves(row) }
      dropped = fields.reject { |path, _| @snapshot.configuration.imported_path?(resource, path) }
      dropped.group_by(&:first).sort.to_h.transform_values do |entries|
        { present: entries.size, nonblank: entries.count { |_, value| value == false || value.present? } }
      end
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
