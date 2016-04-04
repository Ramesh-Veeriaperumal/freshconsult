class AddMobileTokenRefreshedAtToFreshfoneUsers < ActiveRecord::Migration

	shard :all

  def self.up
		Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
	    m.add_column :mobile_token_refreshed_at, "datetime"
		end
  end

  def self.down
		Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
    	m.remove_column :mobile_token_refreshed_at
		end
  end
end
