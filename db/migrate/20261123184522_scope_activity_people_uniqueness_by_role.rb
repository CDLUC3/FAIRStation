class ScopeActivityPeopleUniquenessByRole < ActiveRecord::Migration[8.1]
  ROLE_INDEX = "index_activity_people_on_activity_person_and_role"

  def up
    # MySQL allows duplicate NULLs in unique indexes. Index nil as 'missing' and
    # prefix real roles so a literal role named 'missing' has its own key.
    add_index :activity_people, "research_activity_id, person_id, (COALESCE(CONCAT('role:', role), 'missing'))",
      unique: true, name: ROLE_INDEX
    remove_index :activity_people, [ :research_activity_id, :person_id ], unique: true
  end

  def down
    if multiple_roles_per_person?
      raise ActiveRecord::IrreversibleMigration, "Cannot restore one link per project and person while multiple role links exist."
    end

    add_index :activity_people, [ :research_activity_id, :person_id ], unique: true
    remove_index :activity_people, name: ROLE_INDEX
  end

  private

  def multiple_roles_per_person?
    select_value(<<~SQL).present?
      SELECT 1 FROM activity_people
      GROUP BY research_activity_id, person_id
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
  end
end
