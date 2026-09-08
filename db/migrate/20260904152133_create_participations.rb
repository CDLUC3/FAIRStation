class CreateParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :participations do |t|
      t.references :research_activity, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :organization, null: true, foreign_key: true
      t.string :source, null: false
      t.string :source_id, null: false
      t.string :role, null: false

      t.timestamps
    end


    add_index :participations, %i[source source_id], unique: true
  end
end
