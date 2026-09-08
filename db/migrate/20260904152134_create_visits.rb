class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :research_activity, null: false, foreign_key: true
      t.references :station, null: false, foreign_key: true
      t.string :source, null: false
      t.string :source_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :source_status

      t.timestamps
    end


    add_index :visits, %i[source source_id], unique: true
  end
end
