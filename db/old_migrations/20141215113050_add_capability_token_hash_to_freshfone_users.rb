class AddCapabilityTokenHashToFreshfoneUsers < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
      m.add_column :capability_token_hash, "TEXT DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
      m.remove_column :capability_token_hash
    end
  end
end
