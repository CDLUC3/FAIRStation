class ExpandResearchActivityThesisTitle < ActiveRecord::Migration[8.1]
  def up
    change_column :research_activities, :thesis_title, :text
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "RAMS thesis titles exceed the old 255-character limit"
  end
end
