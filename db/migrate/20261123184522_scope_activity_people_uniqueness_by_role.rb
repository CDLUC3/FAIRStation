class ScopeActivityPeopleUniquenessByRole < ActiveRecord::Migration[8.1]
  def change
    # MySQL allows duplicate NULLs in unique indexes. Index nil as 'missing' and
    # prefix real roles so a literal role named 'missing' has its own key.
    add_index :activity_people, "research_activity_id, person_id, (COALESCE(CONCAT('role:', role), 'missing'))",
      unique: true, name: "index_activity_people_on_activity_person_and_role"
    remove_index :activity_people, [ :research_activity_id, :person_id ], unique: true
  end
end
