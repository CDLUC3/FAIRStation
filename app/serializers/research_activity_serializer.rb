class ResearchActivitySerializer
  def initialize(activity)
    @activity = activity
  end

  def as_json(*)
    {
      id: activity.id,
      source: activity.source,
      source_id: activity.source_id,
      title: activity.title,
      description: activity.description,
      source_record_created_at: activity.source_record_created_at,
      first_visit_started_at: activity.first_visit_started_at,
      first_visit_evidence_source_id: activity.first_visit_evidence_source_id,
      participations: activity.participations.map { serialize_participation(_1) },
      visits: activity.visits.map { serialize_visit(_1) }
    }
  end

  private

  attr_reader :activity

  def serialize_participation(participation)
    {
      source_id: participation.source_id,
      role: participation.role,
      person: serialize_source_record(participation.person),
      organization: participation.organization && serialize_source_record(participation.organization)
    }
  end

  def serialize_visit(visit)
    {
      source_id: visit.source_id,
      starts_at: visit.starts_at,
      ends_at: visit.ends_at,
      source_status: visit.source_status,
      station: serialize_source_record(visit.station),
      participation_source_ids: visit.participations.map(&:source_id)
    }
  end

  def serialize_source_record(record)
    { source: record.source, source_id: record.source_id, name: record.name }
  end
end
