class AddIndexUserIdAccountIdToMonitorships < ActiveRecord::Migration

  shard :none

  def self.up
  	add_index :monitorships, [:user_id,:account_id], :name => 'index_for_monitorships_on_user_id_account_id'
  end

  def self.down
  	remove_index  :monitorships,  :name=>'index_for_monitorships_on_user_id_account_id'
  end

end
