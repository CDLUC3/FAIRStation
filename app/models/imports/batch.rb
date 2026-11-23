module Imports
  # Proposed attributes and source-local links, before any database writes.
  class Batch < Data.define(:source, :stations, :people, :activities, :memberships, :activity_roles)
    StationInput = Data.define(:external_id, :attributes)
    PersonInput = Data.define(:external_id, :attributes)
    ActivityInput = Data.define(:external_id, :attributes, :station_ids)
    MembershipInput = Data.define(:external_id, :attributes, :activity_id, :person_id)
    ActivityRoleInput = Data.define(:external_id, :role, :activity_id, :person_id)

    def initialize(activity_roles: [], **attributes)
      super(**attributes, activity_roles: activity_roles)
    end
  end
end
