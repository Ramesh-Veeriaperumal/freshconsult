# frozen_string_literal: true

class AddSettingsToFreshcallerAccounts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :freshcaller_accounts, atomic_switch: true do |t|
      t.add_column :settings, :text
    end
  end

  def down
    Lhm.change_table :freshcaller_accounts, atomic_switch: true do |t|
      t.remove_column :settings, :text
    end
  end
end
