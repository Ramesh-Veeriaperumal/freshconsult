class AddIndexTimeZoneOnAccounts < ActiveRecord::Migration
  def self.up
  	add_index :accounts, :time_zone, :name => 'index_accounts_on_time_zone'
  end

  def self.down
  	remove_index :accounts, :time_zone
  end
end
