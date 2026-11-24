class TrackActivityPersonAssignmentIdentities < ActiveRecord::Migration[8.1]
  def up
    add_column :source_identifiers, :activity_person_assignment, :boolean, default: false, null: false
    # Tag assignments already imported by development databases on the feature branch.
    execute <<~SQL
      UPDATE source_identifiers SET activity_person_assignment = TRUE
      WHERE record_type = 'ActivityPerson' AND source_system = 'rams'
      AND REGEXP_LIKE(external_id, '^project/[0-9]+/(owner|applicant)$', 'c')
    SQL
  end

  def down
    remove_column :source_identifiers, :activity_person_assignment
  end
end
