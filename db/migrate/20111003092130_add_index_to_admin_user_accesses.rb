class AddIndexToAdminUserAccesses < ActiveRecord::Migration
  
  def self.up
    remove_index(:admin_user_accesses, :name => 'index_admin_user_accesses_on_account_id_and_created_at')
    add_index :admin_user_accesses, [:account_id,:accessible_type,:accessible_id], :name => 'index_admin_user_accesses_on_account_id_and_acc_type_and_acc_id'
    add_index :agent_groups, [:group_id, :user_id], :name => 'agent_groups_group_user_ids'
  end

  def self.down
     remove_index(:admin_user_accesses, :name => 'index_admin_user_accesses_on_account_id_and_acc_type_and_acc_id')
     remove_index(:agent_groups, :name => 'agent_groups_group_user_ids')
     add_index :admin_user_accesses, [:account_id, :created_at], :name => 'index_admin_user_accesses_on_account_id_and_created_at'
  end
end
