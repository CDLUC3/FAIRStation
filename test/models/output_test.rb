require "test_helper"

class OutputTest < ActiveSupport::TestCase
  test "a paper without a DOI can be identified by its provider" do
    output = Output.create!(kind: "paper")
    identifier = output.source_identifiers.create!(source_system: "catalog", source_instance: "public", external_id: "42")
    assert_equal output, identifier.reload.record
  end

  test "normalizes DOIs and rejects duplicate works with the same DOI" do
    output = Output.create!(kind: "paper", doi: " HTTPS://DOI.ORG/10.1234/OAK ")
    assert_equal "10.1234/oak", output.doi

    duplicate = Output.new(kind: "dataset", doi: "10.1234/oak")
    assert_not duplicate.valid?
    assert duplicate.errors[:doi].any?
    assert_raises ActiveRecord::RecordNotUnique do
      Output.insert_all!([ { kind: "dataset", doi: "10.1234/oak" } ])
    end
  end

  test "allows multiple outputs without DOIs" do
    Output.create!(kind: "paper")
    output = Output.create!(kind: "dataset", doi: " ")

    assert_nil output.doi
  end

  test "rejects an unknown kind" do
    assert_not Output.new(kind: "station").valid?
  end
end
