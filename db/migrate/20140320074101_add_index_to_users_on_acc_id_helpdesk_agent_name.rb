class AddIndexToUsersOnAccIdHelpdeskAgentName < ActiveRecord::Migration
  shard :all	
  def self.up
  	Lhm.change_table :users, :atomic_switch => true do |m|
  		m.add_index [:account_id, :helpdesk_agent, :name] , 'index_users_acc_id_name'
  	end
  end

  def self.down
  	Lhm.change_table :users, :atomic_switch => true do |m|
  		m.remove_index [:account_id, :helpdesk_agent, :name] ,'index_users_acc_id_name'
  	end 	
  end
end
