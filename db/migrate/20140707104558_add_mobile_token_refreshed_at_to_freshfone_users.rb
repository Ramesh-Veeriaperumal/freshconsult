class AddMobileTokenRefreshedAtToFreshfoneUsers < ActiveRecord::Migration

	shard :all

  def self.up
		Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
	    m.add_column :mobile_token_refreshed_at, "datetime"
			m.remove_index [:account_id, :presence]
			m.add_index [:account_id, :presence, :mobile_token_refreshed_at], :index_on_account_id_and_presence_and_mobile_token_refreshed_at
		end
  end

  def self.down
		Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
			m.remove_index [:account_id, :presence, :mobile_token_refreshed_at], :index_on_account_id_and_presence_and_mobile_token_refreshed_at
    	m.remove_column :mobile_token_refreshed_at
			m.add_index [:account_id, :presence]
		end
  end
end
