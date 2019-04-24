class AddUuidToAccounts < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :accounts, :atomic_switch => true do |m|
      m.add_column :freshid_account_id, "bigint unsigned DEFAULT NULL"
    end
  end

  def down
    Lhm.change_table :accounts do |m|
      m.remove_column :freshid_account_id
    end
  end
end
