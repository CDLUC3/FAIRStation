class CreateSourceIdentifiers < ActiveRecord::Migration[8.1]
  def change
    create_table :source_identifiers do |t|
      t.references :record, polymorphic: true, null: false
      t.string :source_system, null: false
      t.string :external_id, null: false

      t.timestamps
    end

    add_index :source_identifiers, [ :source_system, :external_id ], unique: true
  end
end
