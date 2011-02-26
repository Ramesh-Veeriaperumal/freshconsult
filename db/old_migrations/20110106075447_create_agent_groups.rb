class CreateAgentGroups < ActiveRecord::Migration
  def self.up
    create_table :agent_groups do |t|
      t.integer :user_id
      t.integer :group_id

      t.timestamps
    end
  end

  def self.down
    drop_table :agent_groups
  end
end
