module Rams
  module FieldComparison
    def self.call(source, stored, expected: source)
      { source: source, stored: stored, matches: equivalent?(expected, stored) }
    end

    def self.equivalent?(expected, stored)
      return expected == stored if expected.nil? || stored.nil?
      if expected.is_a?(String) && stored.is_a?(String) && expected.match?(/\A\d{4}-\d{2}-\d{2}T/)
        return Time.iso8601(expected) == Time.iso8601(stored)
      end
      return expected.to_f == stored.to_f if expected.is_a?(Numeric) || stored.is_a?(Numeric)
      expected == stored
    end
  end
end
