module Rams
  Page = Data.define(:records, :number, :per_page, :total_pages, :total_count) do
    def self.parse(payload, number:, resource:)
      meta = payload.fetch("meta")
      page = new(records: payload.fetch("data"), number: meta.fetch("page"),
        per_page: meta.fetch("per_page"), total_pages: meta.fetch("total_pages"), total_count: meta.fetch("total_count"))
      page.validate!(expected_number: number, resource: resource)
      page
    rescue KeyError, TypeError, NoMethodError
      raise Error, "Invalid RAMS collection for #{resource}"
    end

    def validate!(expected_number:, resource:)
      valid_numbers = [ number, per_page, total_pages, total_count ].all? { |value| value.is_a?(Integer) && value >= 0 }
      unless valid_numbers && per_page.positive? && number == expected_number && records.is_a?(Array)
        raise Error, "Invalid RAMS pagination for #{resource}"
      end
      raise Error, "Invalid RAMS page count for #{resource}" unless total_pages == (total_count.to_f / per_page).ceil
    end

    def verify_consistency!(other, resource:)
      unless [ total_count, total_pages, per_page ] == [ other.total_count, other.total_pages, other.per_page ]
        raise Error, "RAMS counts changed during #{resource} pull; retry the full run"
      end
    end
  end
end
