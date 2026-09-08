class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :source, null: false
      t.string :source_id, null: false
      t.string :name, null: false

      t.timestamps
    end


    add_index :organizations, %i[source source_id], unique: true
  end
end
