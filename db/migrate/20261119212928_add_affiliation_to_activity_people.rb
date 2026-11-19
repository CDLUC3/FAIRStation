class AddAffiliationToActivityPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_people, :affiliation_source_id, :string
    add_column :activity_people, :affiliation_name, :string
    add_column :activity_people, :affiliation_ror_id, :string
  end
end
