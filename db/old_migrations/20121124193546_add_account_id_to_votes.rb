class AddAccountIdToVotes < ActiveRecord::Migration
  def self.up
  	add_column :votes, :account_id, "bigint unsigned"
  end

  def self.down
  	remove_column :votes, :account_id
  end
end
