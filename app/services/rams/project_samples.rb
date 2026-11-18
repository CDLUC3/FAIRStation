module Rams
  # Sample selection and source rechecks for an explicit diagnostic run.
  class ProjectSamples
    attr_reader :today

    def initialize(snapshot:, today:)
      @snapshot, @today = snapshot, today
    end

    def groups
      { "current" => @snapshot.rows("projects").select { |row| current?(row) }.first(3),
        "historical" => @snapshot.rows("projects").select { |row| historical?(row) }.last(5) }
    end

    def shortfall
      { current: 3 - groups.fetch("current").size, historical: 5 - groups.fetch("historical").size }
    end

    def verify!(client:)
      groups.values.flatten.each do |row|
        raise Error, "Project #{row['id']} changed during diagnostic pull; rerun" unless client.record("projects", row.fetch("id")) == row
      end
    end

    private

    def current?(row)
      row.fetch("status") == "open" && (row["end_date"].blank? || Date.iso8601(row.fetch("end_date")) >= today)
    end

    def historical?(row)
      row.fetch("status") == "closed" || (row["end_date"].present? && Date.iso8601(row.fetch("end_date")) < today)
    end
  end
end
