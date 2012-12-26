class AddAccountIdToMonitorships < ActiveRecord::Migration
  def self.up
  	add_column :monitorships, :account_id, "bigint unsigned"
  end

  def self.down
  	remove_column :monitorships, :account_id
  end
end
