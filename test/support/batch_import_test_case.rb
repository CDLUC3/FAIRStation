require "test_helper"

class BatchImportTestCase < ActiveSupport::TestCase
  def batch(instance: "installation-a", station_id: "station-a", title: "Translated activity")
    Imports::Batch.new(source: { source_system: "another_source", source_instance: instance },
      stations: [ Imports::Batch::StationInput.new(external_id: station_id, attributes: { name: "Translated station" }) ],
      people: [ Imports::Batch::PersonInput.new(external_id: "person-a", attributes: { name: "Translated person", orcid: nil }) ],
      activities: [ Imports::Batch::ActivityInput.new(external_id: "activity-a", attributes: { title: title, activity_type: "research", status: "open" }, station_ids: [ station_id ]) ],
      memberships: [ Imports::Batch::MembershipInput.new(external_id: "membership-a", attributes: { role: "researcher", active: true, is_principal_investigator: false }, activity_id: "activity-a", person_id: "person-a") ])
  end

  def import(batch)
    ApplicationRecord.transaction { Imports::BatchImport.new(batch: batch).call }
  end
end
