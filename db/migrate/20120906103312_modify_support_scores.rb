class ModifySupportScores < ActiveRecord::Migration
  def self.up
  	rename_column :support_scores, :agent_id, :user_id
  end

  def self.down
  	rename_column :support_scores, :user_id, :agent_id
  end
end
