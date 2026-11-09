require "test_helper"

class ActivityStationTest < ActiveSupport::TestCase
  test "requires both records" do
    link = ActivityStation.new
    assert_not link.valid?
    assert_includes link.errors[:research_activity], "must exist"
    assert_includes link.errors[:station], "must exist"
  end

  test "prevents duplicate station links in model and database" do
    station = Station.create!(name: "Quail Ridge")
    activity = ResearchActivity.create!(stations: [ station ])
    assert_not ActivityStation.new(research_activity: activity, station: station).valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      ActivityStation.insert_all!([ { research_activity_id: activity.id, station_id: station.id } ])
    end
  end

  test "cannot destroy a station linked to research" do
    station = Station.create!(name: "Quail Ridge")
    activity = ResearchActivity.create!(stations: [ station ])
    assert_not station.destroy
    assert_equal [ station ], activity.reload.stations.to_a
  end
end
