class CreateStations < ActiveRecord::Migration[8.1]
  def change
    create_table :stations do |t|
      t.string :name, null: false
      t.string :short_name
      t.text :description
      t.string :ror_id, :doi
      t.decimal :latitude, :longitude, precision: 10, scale: 6

      t.timestamps
    end
  end
end
