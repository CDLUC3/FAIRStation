class AddSourceInstanceToSourceIdentifiers < ActiveRecord::Migration[8.1]
  def up
    add_column :source_identifiers, :source_instance, :string

    # UC Nature is the only RAMS installation imported before this migration.
    execute "UPDATE source_identifiers SET source_instance = 'ucnature' WHERE source_system = 'rams'"
    change_column_null :source_identifiers, :source_instance, false

    add_index :source_identifiers, [ :source_system, :source_instance, :external_id ],
      unique: true, name: "index_source_identifiers_on_source_identity"
    remove_index :source_identifiers, [ :source_system, :external_id ]
  end

  def down
    add_index :source_identifiers, [ :source_system, :external_id ], unique: true
    remove_index :source_identifiers, name: "index_source_identifiers_on_source_identity"
    remove_column :source_identifiers, :source_instance
  end
end
