class CreateResearchActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :research_activities do |t|
      t.string :source, null: false
      t.string :source_id, null: false
      t.string :title, null: false
      t.text :description
      t.datetime :source_record_created_at
      t.datetime :first_visit_started_at
      t.string :first_visit_evidence_source_id

      t.timestamps
    end

    add_index :research_activities, %i[source source_id], unique: true
  end
end
