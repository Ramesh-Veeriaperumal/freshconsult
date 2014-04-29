class AddIndexToAdminUserAccessesOnType < ActiveRecord::Migration
  shard :all	
  def self.up
  	Lhm.change_table :admin_user_accesses, :atomic_switch => true do |m|
  		m.add_index [:account_id, :accessible_id, :accessible_type] , 'index_admin_acc_id_type'
	end	
  end

  def self.down
  	Lhm.change_table :admin_user_accesses, :atomic_switch => true do |m|
  		m.remove_index [:account_id, :accessible_id, :accessible_type] , 'index_admin_acc_id_type'
	end	
  end
end
