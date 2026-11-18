module Imports
  # Proposed attributes and source-local links, before any database writes.
  class Batch < Data.define(:source, :stations, :people, :activities, :memberships)
    StationInput = Data.define(:external_id, :attributes)
    PersonInput = Data.define(:external_id, :attributes)
    ActivityInput = Data.define(:external_id, :attributes, :station_ids)
    MembershipInput = Data.define(:external_id, :attributes, :activity_id, :person_id)
  end
end
