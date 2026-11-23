module Imports
  # Proposed attributes and source-local links, before any database writes.
  class Batch < Data.define(:source, :stations, :people, :activities, :memberships, :assignments)
    StationInput = Data.define(:external_id, :attributes)
    PersonInput = Data.define(:external_id, :attributes)
    ActivityInput = Data.define(:external_id, :attributes, :station_ids)
    MembershipInput = Data.define(:external_id, :attributes, :activity_id, :person_id)
    # The source ID identifies a role on the activity independently of its assignee.
    AssignmentInput = Data.define(:external_id, :role, :activity_id, :person_id)

    def initialize(assignments: [], **attributes)
      super(**attributes, assignments: assignments)
    end
  end
end
