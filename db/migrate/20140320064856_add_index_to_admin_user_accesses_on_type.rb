class AddIndexToAdminUserAccessesOnType < ActiveRecord::Migration
  shard :all	
  def self.up
  	add_index :admin_user_accesses, [:account_id, :accessible_id, :accessible_type], :name => 'index_admin_user_accesses_on_account_id_accessible_id_and_accessible_type' 
  end

  def self.down
  	remove_index(:admin_user_accesses, :name => 'index_admin_user_accesses_on_account_id_accessible_id_and_accessible_type)
  end
end
