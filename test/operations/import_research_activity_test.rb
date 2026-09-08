require "test_helper"

class ImportResearchActivityTest < ActiveSupport::TestCase
  FakeAdapter = Struct.new(:activity, :requested_source_id) do
    def fetch_research_activity(source_id)
      self.requested_source_id = source_id
      activity
    end
  end

  test "pulls and stores a graph while retaining the activity identity on repeat import" do
    source_activity = mapped_activity
    adapter = FakeAdapter.new(source_activity)

    activity = ImportResearchActivity.new.call(adapter:, source_id: "projects/123")
    original_id = activity.id
    source_activity.title = "Updated title"
    updated_activity = ImportResearchActivity.new.call(adapter:, source_id: "projects/123")

    assert_equal "projects/123", adapter.requested_source_id
    assert_equal original_id, updated_activity.id
    assert_equal "Updated title", updated_activity.title
    assert_equal 1, ResearchActivity.count
    assert_equal 2, updated_activity.participations.count
    assert_equal 2, updated_activity.visits.count
    assert_equal [ "project_team_memberships/501" ], updated_activity.visits.find_by!(source_id: "visits/801").participations.pluck(:source_id)
  end

  test "rolls back when the mapped graph contains an unknown attendance" do
    source_activity = mapped_activity
    source_activity.visits.first.visit_participations.first.participation = Participation.new(source_id: "missing")

    assert_raises(KeyError) do
      ImportResearchActivity.new.call(adapter: FakeAdapter.new(source_activity), source_id: "projects/123")
    end
    assert_equal 0, ResearchActivity.count
  end

  private

  def mapped_activity
    payload = JSON.parse(file_fixture("rams/research_activity.json").read)
    RamsAdapter.new(http_client: Struct.new(:payload) do
      def get_json(**) = payload
    end.new(payload)).fetch_research_activity("projects/123")
  end
end
