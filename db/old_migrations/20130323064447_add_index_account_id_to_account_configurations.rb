class AddIndexAccountIdToAccountConfigurations < ActiveRecord::Migration
  def self.up
  	add_index :account_configurations, :account_id, :name => 'index_for_account_configurations_on_account_id'
  end

  def self.down
  	remove_index :account_configurations, :account_id
  end
end
