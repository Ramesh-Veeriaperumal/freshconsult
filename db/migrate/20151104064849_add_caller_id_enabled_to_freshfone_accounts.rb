class AddCallerIdEnabledToFreshfoneAccounts < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.add_column :caller_id_enabled, 'tinyint(1) DEFAULT false'
    end
  end

  def down
    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.remove_column :caller_id_enabled
    end
  end
end
