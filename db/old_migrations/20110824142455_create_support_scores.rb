class CreateSupportScores < ActiveRecord::Migration
  def self.up
    create_table :support_scores do |t|
      t.integer :account_id, :limit => 8
      t.integer :agent_id, :limit => 8
      t.integer :scorable_id, :limit => 8
      t.string :scorable_type
      t.integer :score

      t.timestamps
    end
  end

  def self.down
    drop_table :support_scores
  end
end
