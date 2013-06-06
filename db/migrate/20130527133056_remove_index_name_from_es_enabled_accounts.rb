class RemoveIndexNameFromEsEnabledAccounts < ActiveRecord::Migration
  def self.up
    Lhm.change_table :es_enabled_accounts, :atomic_switch => true do |m|
      m.remove_column :index_name
    end
  end

  def self.down
    Lhm.change_table :es_enabled_accounts, :atomic_switch => true do |m|
      m.add_column :index_name, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    end
  end
end
