class WhitelistUsers < ActiveRecord::Migration
	shard :shard_1
  def self.up
  	create_table :whitelist_users do |t|  
  	  t.column :user_id, "bigint unsigned"
  	  t.column :account_id, "bigint unsigned"
  	end   
  end

  def self.down
  	drop_table :whitelist_users
  end
end
