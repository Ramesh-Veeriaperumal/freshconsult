class AddAdditionalSettingsToAccountAdditionalSettings < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :account_additional_settings, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s ADD COLUMN additional_settings text " % m.name)
    end
  end

  def self.down
     Lhm.change_table :account_additional_settings, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s DROP COLUMN additional_settings " % m.name)
    end
  end
end
