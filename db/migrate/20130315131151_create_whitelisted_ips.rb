class CreateWhitelistedIps < ActiveRecord::Migration
  shard :none
  def self.up
  	create_table :whitelisted_ips do |t|
  		t.column :account_id, "bigint unsigned"
      t.boolean :enabled
  		t.text :ip_ranges
  		t.boolean :applies_only_to_agents
  		t.timestamps
  	end
  end

  def self.down
  	drop_table :whitelisted_ips
  end
end
