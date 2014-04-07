class AddIndexToUsersOnAccIdHelpdeskAgentName < ActiveRecord::Migration
  shard :all	
  def self.up
  	add_index :users, [:account_id, :helpdesk_agent, :name], :name => 'index_users_on_acc_id_helpdek_agent_name'
  end

  def self.down
  	remove_index(:users, :name => 'index_users_on_acc_id_helpdek_agent_name')
  end
end
