require "test_helper"

class RamsAdapterTest < ActiveSupport::TestCase
  FakeHttpClient = Struct.new(:payload, :requested_path, :requested_headers) do
    def get_json(path:, headers:)
      self.requested_path = path
      self.requested_headers = headers
      payload
    end
  end

  test "requests and maps a connected RAMS research activity" do
    client = FakeHttpClient.new(payload)
    activity = adapter(http_client: client).fetch_research_activity("projects/123")

    assert_equal "api/fair_station/v1/research_activities/projects/123", client.requested_path
    assert_equal "Bearer secret", client.requested_headers.fetch("Authorization")
    assert_equal "rams", activity.source
    assert_equal "projects/123", activity.source_id
    assert_equal 2, activity.participations.size
    assert_equal "users/41", activity.participations.first.person.source_id
    assert_equal "institutions/8", activity.participations.first.organization.source_id
    assert_nil activity.participations.second.organization
    assert_equal 2, activity.visits.size
    assert_equal "reserves/12", activity.visits.first.station.source_id
    assert_equal "project_team_memberships/501", activity.visits.first.visit_participations.first.participation.source_id
  end

  test "derives the first visit only from completed, non-future RAMS visits" do
    activity = adapter.fetch_research_activity("projects/123")

    assert_equal Time.zone.parse("2025-06-03T16:00:00Z"), activity.first_visit_started_at
    assert_equal "visits/801", activity.first_visit_evidence_source_id
  end

  test "rejects a non-research RAMS project" do
    payload["type"] = "Education"

    assert_raises(RamsAdapter::UnsupportedProject) do
      adapter.fetch_research_activity("projects/123")
    end
  end

  private

  def adapter(http_client: FakeHttpClient.new(payload))
    RamsAdapter.new(
      http_client:,
      token: "secret",
      clock: Struct.new(:current).new(Time.zone.parse("2025-07-01T00:00:00Z"))
    )
  end

  def payload
    @payload ||= JSON.parse(file_fixture("rams/research_activity.json").read)
  end
end
