class AddSubCategoryToQuests < ActiveRecord::Migration
  def self.up
  	rename_column :quests, :quest_type, :category
  	add_column :quests, :sub_category, :integer
  	change_column :quests, :points, :integer, :default => 0
  end

  def self.down
  	rename_column :quests, :category, :quest_type
  	remove_column :quests, :sub_category
  	change_column :quests, :points, :integer
  end
end
