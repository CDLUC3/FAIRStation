require "test_helper"

class StationTest < ActiveSupport::TestCase
  test "requires a name" do
    station = Station.new

    assert_not station.valid?
    assert_includes station.errors[:name], "can't be blank"
  end

  test "links to source records without source-specific columns" do
    station = Station.create!(name: "Quail Ridge Reserve")
    identifier = station.source_identifiers.create!(source_system: "rams", source_instance: "ucnature", external_id: "17")

    assert_equal station, identifier.record
  end
end
