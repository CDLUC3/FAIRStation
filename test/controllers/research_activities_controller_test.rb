require "test_helper"

class ResearchActivitiesControllerTest < ActionDispatch::IntegrationTest
  test "shows a stored research activity as an explicit connected representation" do
    payload = JSON.parse(file_fixture("rams/research_activity.json").read)
    http_client = Struct.new(:payload) do
      def get_json(**) = payload
    end.new(payload)
    adapter = RamsAdapter.new(http_client:)
    activity = ImportResearchActivity.new.call(adapter:, source_id: "projects/123")

    get research_activity_url(activity), as: :json

    assert_response :success
    response_body = response.parsed_body
    assert_equal "projects/123", response_body.fetch("source_id")
    assert_equal "project_team_memberships/501", response_body.fetch("participations").first.fetch("source_id")
    assert_equal "reserves/12", response_body.fetch("visits").first.fetch("station").fetch("source_id")
  end
end
