class AddLastCallAtToFreshfoneUsers < ActiveRecord::Migration
  shard :all

  def self.up
    add_column :freshfone_users, :last_call_at, :datetime
    add_index :freshfone_users, [:account_id, :last_call_at], 
      :name => 'index_ff_users_account_last_call'
  end

  def self.down
    remove_column :freshfone_users, :last_call_at
    remove_index :freshfone_users, :name => 'index_ff_users_account_last_call'
  end

end
