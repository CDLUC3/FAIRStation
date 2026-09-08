class CreateVisitParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :visit_participations do |t|
      t.references :visit, null: false, foreign_key: true
      t.references :participation, null: false, foreign_key: true
      t.string :source, null: false
      t.string :source_id, null: false
      t.datetime :arrives_at
      t.datetime :departs_at

      t.timestamps
    end


    add_index :visit_participations, %i[source source_id], unique: true
    add_index :visit_participations, %i[visit_id participation_id], unique: true
  end
end
