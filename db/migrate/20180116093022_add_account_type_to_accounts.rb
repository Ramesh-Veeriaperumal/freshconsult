class AddAccountTypeToAccounts < ActiveRecord::Migration
	shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :accounts, :atomic_switch => true do |m|
      m.add_column :account_type, "tinyint(4) DEFAULT '0'"
    end
  end

  def down
    Lhm.change_table :accounts, :atomic_switch => true do |m|
      m.remove_column :account_type
    end
  end

end
