class ModifySupportScores < ActiveRecord::Migration
  def self.up
  	rename_column :support_scores, :agent_id, :user_id
  	remove_column :support_scores, :badge
  end

  def self.down
  	add_column :support_scores, :badge, :string
  	rename_column :support_scores, :user_id, :agent_id
  end
end
