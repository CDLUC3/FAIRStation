require "test_helper"

class SourceIdentifierTest < ActiveSupport::TestCase
  setup do
    @station = Station.create!(name: "Quail Ridge Reserve")
  end

  test "requires a source system and external id" do
    identifier = SourceIdentifier.new(record: @station)

    assert_not identifier.valid?
    assert_includes identifier.errors[:source_system], "can't be blank"
    assert_includes identifier.errors[:external_id], "can't be blank"
  end

  test "rejects an external id already attached within the same source system" do
    SourceIdentifier.create!(record: @station, source_system: "reservation_system", external_id: "17")
    duplicate = SourceIdentifier.new(
      record: Station.create!(name: "Another Reserve"),
      source_system: "reservation_system",
      external_id: "17"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "allows the same external id in another source system" do
    SourceIdentifier.create!(record: @station, source_system: "reservation_system", external_id: "17")
    identifier = SourceIdentifier.new(record: @station, source_system: "intake_form", external_id: "17")

    assert identifier.valid?
  end

  test "enforces external id uniqueness in the database" do
    SourceIdentifier.create!(record: @station, source_system: "reservation_system", external_id: "17")

    assert_raises(ActiveRecord::RecordNotUnique) do
      SourceIdentifier.insert_all!([ {
        record_type: "Station",
        record_id: @station.id,
        source_system: "reservation_system",
        external_id: "17"
      } ])
    end
  end
end
