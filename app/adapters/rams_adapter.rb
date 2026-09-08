class RamsAdapter
  class UnsupportedProject < StandardError; end
  class InvalidPayload < StandardError; end

  QUALIFYING_VISIT_STATUSES = %w[completed].freeze

  def self.build
    new(
      http_client: HttpClient.new(base_url: ENV.fetch("RAMS_BASE_URL")),
      token: ENV["RAMS_API_TOKEN"]
    )
  end

  def initialize(http_client:, token: nil, clock: Time)
    @http_client = http_client
    @token = token
    @clock = clock
  end

  def fetch_research_activity(source_id)
    map(http_client.get_json(path: endpoint_path(source_id), headers: request_headers))
  end

  private

  attr_reader :http_client, :token, :clock

  def map(payload)
    require_research_project!(payload)
    activity = build_activity(payload)
    participations = map_participations(activity, payload.fetch("team_members"))
    map_visits(activity, participations, payload.fetch("visits"))
    set_first_visit_milestone(activity)
    activity
  rescue KeyError, TypeError, ArgumentError => error
    raise InvalidPayload, "RAMS payload does not satisfy the import contract: #{error.message}"
  end

  def build_activity(payload)
    ResearchActivity.new(
      source: "rams",
      source_id: source_id("projects", payload.fetch("id")),
      title: payload.fetch("title"),
      description: payload["description"],
      source_record_created_at: parse_time(payload.fetch("created_at"))
    )
  end

  def map_participations(activity, members)
    members.to_h do |member|
      person = member.fetch("person")
      organization = member["organization"]
      participation = activity.participations.build(
        source: "rams",
        source_id: source_id("project_team_memberships", member.fetch("id")),
        role: member.fetch("role"),
        person: Person.new(source: "rams", source_id: source_id("users", person.fetch("id")), name: person.fetch("name")),
        organization: map_organization(organization)
      )

      [ participation.source_id, participation ]
    end
  end

  def map_organization(organization)
    return unless organization

    Organization.new(
      source: "rams",
      source_id: source_id("institutions", organization.fetch("id")),
      name: organization.fetch("name")
    )
  end

  def map_visits(activity, participations, visits)
    visits.each do |source_visit|
      station = source_visit.fetch("station")
      visit = activity.visits.build(
        source: "rams",
        source_id: source_id("visits", source_visit.fetch("id")),
        starts_at: parse_time(source_visit.fetch("starts_at")),
        ends_at: parse_optional_time(source_visit["ends_at"]),
        source_status: source_visit.fetch("status"),
        station: Station.new(source: "rams", source_id: source_id("reserves", station.fetch("id")), name: station.fetch("name"))
      )

      map_attendances(visit, participations, source_visit.fetch("participants", []))
    end
  end

  def map_attendances(visit, participations, attendances)
    attendances.each do |attendance|
      participation_source_id = source_id("project_team_memberships", attendance.fetch("team_membership_id"))
      participation = participations.fetch(participation_source_id)
      visit.visit_participations.build(
        source: "rams",
        source_id: source_id("user_visits", attendance.fetch("id")),
        participation:,
        arrives_at: parse_optional_time(attendance["arrives_at"]),
        departs_at: parse_optional_time(attendance["departs_at"])
      )
    end
  end

  def set_first_visit_milestone(activity)
    first_visit = activity.visits.select do |visit|
      QUALIFYING_VISIT_STATUSES.include?(visit.source_status) && visit.starts_at <= clock.current
    end.min_by(&:starts_at)

    activity.first_visit_started_at = first_visit&.starts_at
    activity.first_visit_evidence_source_id = first_visit&.source_id
  end

  def require_research_project!(payload)
    return if payload.fetch("type") == "Research"

    raise UnsupportedProject, "RAMS project type must be Research"
  end

  def endpoint_path(source_id)
    escaped_source_id = source_id.split("/").map { URI.encode_uri_component(_1) }.join("/")
    "api/fair_station/v1/research_activities/#{escaped_source_id}"
  end

  def request_headers
    { "Accept" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token.present?
    end
  end

  def source_id(collection, id)
    "#{collection}/#{id}"
  end

  def parse_time(value)
    Time.zone.parse(value).presence || raise(ArgumentError, "invalid time #{value.inspect}")
  end

  def parse_optional_time(value)
    parse_time(value) if value.present?
  end
end
