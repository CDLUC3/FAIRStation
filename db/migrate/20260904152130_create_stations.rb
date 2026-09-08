class CreateStations < ActiveRecord::Migration[8.1]
  def change
    create_table :stations do |t|
      t.string :source, null: false
      t.string :source_id, null: false
      t.string :name, null: false

      t.timestamps
    end


    add_index :stations, %i[source source_id], unique: true
  end
end
