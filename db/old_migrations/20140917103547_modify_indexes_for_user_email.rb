class ModifyIndexesForUserEmail < ActiveRecord::Migration
	shard :all
  def self.up
  	Lhm.change_table :user_emails, {:atomic_switch => true, :start => 0, :limit => 0} do |m|
  		m.remove_index [:user_id, :account_id]
  		m.remove_index [:user_id, :primary_role]
  		m.add_index [:account_id, :perishable_token], "index_account_id_perishable_token"
  		m.add_index [:account_id, :user_id, :primary_role], "index_account_id_user_id_primary_role"
      m.ddl("ALTER TABLE %s ADD PRIMARY KEY(id, account_id)" % m.name)
  	end
  end

  def self.down
  	Lhm.change_table :user_emails, {:atomic_switch => true, :start => 0, :limit => 0} do |m|
      m.ddl("ALTER TABLE %s DROP PRIMARY KEY" % m.name)
  		m.remove_index [:account_id, :user_id, :primary_role], "index_account_id_user_id_primary_role"
  		m.remove_index [:account_id, :perishable_token], "index_account_id_perishable_token"
  		m.add_index [:user_id, :primary_role]
  		m.add_index [:user_id, :account_id]
  	end
  end
end
