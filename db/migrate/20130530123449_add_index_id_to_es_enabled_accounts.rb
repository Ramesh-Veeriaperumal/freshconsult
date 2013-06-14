class AddIndexIdToEsEnabledAccounts < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :es_enabled_accounts, :atomic_switch => true do |m|
      m.add_column :index_id, "bigint unsigned"
    end
  end

  def self.down
    Lhm.change_table :es_enabled_accounts, :atomic_switch => true do |m|
      m.remove_column :index_id
    end
  end
end
