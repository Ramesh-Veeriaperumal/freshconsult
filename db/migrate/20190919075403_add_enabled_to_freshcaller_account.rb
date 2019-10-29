class AddEnabledToFreshcallerAccount < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :freshcaller_accounts, atomic_switch: true do |t|
      t.add_column :enabled, "tinyint(1) DEFAULT '1'"
    end
  end

  def down
    Lhm.change_table :freshcaller_accounts, atomic_switch: true do |t|
      t.remove_column :enabled
    end
  end
end
