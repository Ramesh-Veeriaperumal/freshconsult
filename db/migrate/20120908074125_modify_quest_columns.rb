class ModifyQuestColumns < ActiveRecord::Migration
  def self.up
  	rename_column :quests, :questtype, :quest_type
  	remove_column :quests, :award_data
  	add_column :quests, :points, :integer
  	add_column :quests, :badge_id, :integer
  end

  def self.down
  	rename_column :quests, :quest_type, :questtype
  	add_column :quests, :award_data
  	remove_column :quests, :points
  	remove_column :quests, :badge_id
  end
end
