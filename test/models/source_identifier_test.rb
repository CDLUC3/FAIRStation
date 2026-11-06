require "test_helper"

class SourceIdentifierTest < ActiveSupport::TestCase
  setup do
    @station = Station.create!(name: "Quail Ridge Reserve")
  end

  test "requires a source system, instance, and external id" do
    identifier = SourceIdentifier.new(record: @station)

    assert_not identifier.valid?
    assert_includes identifier.errors[:source_system], "can't be blank"
    assert_includes identifier.errors[:source_instance], "can't be blank"
    assert_includes identifier.errors[:external_id], "can't be blank"
  end

  test "rejects an external id already attached within the same source installation" do
    SourceIdentifier.create!(record: @station, source_system: "rams", source_instance: "ucnature", external_id: "17")
    duplicate = SourceIdentifier.new(
      record: Station.create!(name: "Another Reserve"),
      source_system: "rams", source_instance: "ucnature",
      external_id: "17"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "allows the same external id in another source system" do
    SourceIdentifier.create!(record: @station, source_system: "rams", source_instance: "ucnature", external_id: "17")
    identifier = SourceIdentifier.new(record: @station, source_system: "intake_form", source_instance: "ucnature", external_id: "17")

    assert identifier.valid?
  end

  test "allows the same external id in another installation of the same system" do
    SourceIdentifier.create!(record: @station, source_system: "rams", source_instance: "ucnature", external_id: "17")
    other_station = Station.create!(name: "Another Reserve")
    identifier = SourceIdentifier.create!(record: other_station, source_system: "rams", source_instance: "umbs", external_id: "17")

    assert_equal other_station, identifier.reload.record
  end

  test "enforces external id uniqueness in the database" do
    SourceIdentifier.create!(record: @station, source_system: "rams", source_instance: "ucnature", external_id: "17")

    assert_raises(ActiveRecord::RecordNotUnique) do
      SourceIdentifier.insert_all!([ {
        record_type: "Station",
        record_id: @station.id,
        source_system: "rams", source_instance: "ucnature",
        external_id: "17"
      } ])
    end
  end
end
