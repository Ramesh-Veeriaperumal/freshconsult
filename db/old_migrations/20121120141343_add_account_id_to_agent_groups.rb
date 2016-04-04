class AddAccountIdToAgentGroups < ActiveRecord::Migration
  def self.up
    add_column :agent_groups, :account_id, "bigint unsigned"
  end

  def self.down
    remove_column :agent_groups, :account_id
  end
end
