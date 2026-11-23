class CreateResearchActivityModels < ActiveRecord::Migration[8.1]
  def change
    create_research_activities
    create_people
    add_index :people, :orcid, unique: true
    create_activity_people
    add_index :activity_people, [ :research_activity_id, :person_id ], unique: true
    create_activity_stations
    add_index :activity_stations, [ :research_activity_id, :station_id ], unique: true
  end

  private

  def create_research_activities
    create_table :research_activities do |t|
      research_activity_fields(t)
      t.timestamps
    end
  end

  def research_activity_fields(t)
    t.string :title
    t.text :description
    t.string :activity_type, :status
    t.date :start_date, :end_date
    t.string :discipline, :discipline_other
    t.text :keywords, :taxonomic_keywords
    t.string :thesis_title, :course_title, :course_number
    t.datetime :submitted_at
  end

  def create_people
    create_table :people do |t|
      t.string :orcid, null: false
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_activity_people
    create_table :activity_people do |t|
      t.references :research_activity, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :role
      t.boolean :active, null: false, default: true
      t.boolean :is_principal_investigator, null: false, default: false
      t.timestamps
    end
  end

  def create_activity_stations
    create_table :activity_stations do |t|
      t.references :research_activity, null: false, foreign_key: true
      t.references :station, null: false, foreign_key: true
      t.timestamps
    end
  end
end
