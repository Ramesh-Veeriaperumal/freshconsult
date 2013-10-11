class CreateGlobalBlacklistedIps < ActiveRecord::Migration
  shard :none
  def self.up
  	create_table :global_blacklisted_ips do |t|
  		t.text :ip_list
  		t.timestamps
  	end
  end

  def self.down
  	drop_table :global_blacklisted_ips
  end
end
