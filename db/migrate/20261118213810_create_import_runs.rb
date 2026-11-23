class CreateImportRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :import_runs do |t|
      t.string :source_system, limit: 128, null: false
      t.string :source_instance, limit: 128, null: false
      t.string :station_external_id, null: false
      t.datetime :retrieved_at, null: false
      t.datetime :successful_at, null: false
      t.text :snapshot_path, null: false
      t.text :metadata_path, null: false
      t.string :snapshot_sha256, limit: 64, null: false
      t.string :metadata_sha256, limit: 64, null: false
      t.timestamps
      t.index [ :source_system, :source_instance, :station_external_id, :successful_at ], name: "index_import_runs_on_source_station_success"
    end
    add_reference :source_identifiers, :import_run, foreign_key: true
  end
end
