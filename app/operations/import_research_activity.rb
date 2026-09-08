class ImportResearchActivity
  def call(adapter:, source_id:)
    persist(adapter.fetch_research_activity(source_id))
  end

  private

  def persist(mapped_activity)
    ResearchActivity.transaction do
      activity = ResearchActivity.find_or_initialize_by(
        source: mapped_activity.source,
        source_id: mapped_activity.source_id
      )
      activity.assign_attributes(mapped_activity.attributes.except("id", "created_at", "updated_at"))
      activity.save!

      replace_connected_records(activity, mapped_activity)
      activity
    end
  end

  def replace_connected_records(activity, mapped_activity)
    activity.visits.destroy_all
    activity.participations.destroy_all

    participations = mapped_activity.participations.to_h do |mapped_participation|
      [ mapped_participation.source_id, create_participation(activity, mapped_participation) ]
    end

    mapped_activity.visits.each do |mapped_visit|
      create_visit(activity, mapped_visit, participations)
    end
  end

  def create_participation(activity, mapped_participation)
    person = upsert_named_source_record(Person, mapped_participation.person)
    organization = upsert_named_source_record(Organization, mapped_participation.organization)

    activity.participations.create!(
      source: mapped_participation.source,
      source_id: mapped_participation.source_id,
      role: mapped_participation.role,
      person:,
      organization:
    )
  end

  def create_visit(activity, mapped_visit, participations)
    station = upsert_named_source_record(Station, mapped_visit.station)
    visit = activity.visits.create!(
      source: mapped_visit.source,
      source_id: mapped_visit.source_id,
      starts_at: mapped_visit.starts_at,
      ends_at: mapped_visit.ends_at,
      source_status: mapped_visit.source_status,
      station:
    )

    mapped_visit.visit_participations.each do |mapped_attendance|
      participation = participations.fetch(mapped_attendance.participation.source_id)
      visit.visit_participations.create!(
        source: mapped_attendance.source,
        source_id: mapped_attendance.source_id,
        participation:,
        arrives_at: mapped_attendance.arrives_at,
        departs_at: mapped_attendance.departs_at
      )
    end
  end

  def upsert_named_source_record(model, mapped_record)
    return unless mapped_record

    model.find_or_initialize_by(source: mapped_record.source, source_id: mapped_record.source_id).tap do |record|
      record.update!(name: mapped_record.name)
    end
  end
end
