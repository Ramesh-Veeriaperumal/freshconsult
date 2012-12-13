class AddAccountIdToAgents < ActiveRecord::Migration
  def self.up
    add_column :agents, :account_id, "bigint unsigned"
  end

  def self.down
    remove_column :agents, :account_id
  end
end
