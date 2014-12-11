class AddSupportTriggerToSupportScores < ActiveRecord::Migration
  def self.up
    add_column :support_scores, :score_trigger, :integer
  end

  def self.down
    remove_column :support_scores, :score_trigger
  end
end
