class CreateResearchActivityModels < ActiveRecord::Migration[8.1]
  def change
    create_table :research_activities do |t|
      t.string :title
      t.text :description
      t.string :activity_type
      t.string :status
      t.date :start_date
      t.date :end_date
      t.string :discipline
      t.string :discipline_other
      t.text :keywords
      t.text :taxonomic_keywords
      t.string :thesis_title
      t.string :course_title
      t.string :course_number
      t.datetime :submitted_at
      t.timestamps
    end

    create_table :people do |t|
      t.string :orcid, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :people, :orcid, unique: true

    create_table :activity_people do |t|
      t.references :research_activity, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :role
      t.boolean :active, null: false, default: true
      t.boolean :is_principal_investigator, null: false, default: false
      t.timestamps
    end
    add_index :activity_people, [ :research_activity_id, :person_id ], unique: true

    create_table :activity_stations do |t|
      t.references :research_activity, null: false, foreign_key: true
      t.references :station, null: false, foreign_key: true
      t.timestamps
    end
    add_index :activity_stations, [ :research_activity_id, :station_id ], unique: true
  end
end
