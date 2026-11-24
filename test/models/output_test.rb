require "test_helper"

class OutputTest < ActiveSupport::TestCase
  test "a paper without a DOI can be identified by its provider" do
    output = Output.create!(kind: "paper")
    identifier = output.source_identifiers.create!(source_system: "catalog", source_instance: "public", external_id: "42")
    assert_equal output, identifier.reload.record
  end

  test "rejects an unknown kind" do
    assert_not Output.new(kind: "station").valid?
  end
end
