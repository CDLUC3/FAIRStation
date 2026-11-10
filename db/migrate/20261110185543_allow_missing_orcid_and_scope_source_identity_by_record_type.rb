class AllowMissingOrcidAndScopeSourceIdentityByRecordType < ActiveRecord::Migration[8.1]
  def up
    change_column_null :people, :orcid, true

    # Keep the full four-column utf8mb4 key within MySQL's 3072-byte limit.
    change_column :source_identifiers, :source_system, :string, limit: 128, null: false
    change_column :source_identifiers, :source_instance, :string, limit: 128, null: false

    remove_index :source_identifiers, [ :source_system, :source_instance, :external_id ],
      unique: true, name: "index_source_identifiers_on_source_identity"
    add_index :source_identifiers, [ :source_system, :source_instance, :record_type, :external_id ],
      unique: true, name: "index_source_identifiers_on_source_identity"
  end

  def down
    remove_index :source_identifiers, name: "index_source_identifiers_on_source_identity"
    change_column :source_identifiers, :source_system, :string, limit: 255, null: false
    change_column :source_identifiers, :source_instance, :string, limit: 255, null: false
    add_index :source_identifiers, [ :source_system, :source_instance, :external_id ],
      unique: true, name: "index_source_identifiers_on_source_identity"
    change_column_null :people, :orcid, false
  end
end
