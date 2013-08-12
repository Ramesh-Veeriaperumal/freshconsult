class AddStatusToDeletedCustomers < ActiveRecord::Migration
	shard :none
	
  def self.up
    add_column :deleted_customers, :status, :integer, :default => 0
  end

  def self.down
    remove_column :deleted_customers, :status
  end
end
