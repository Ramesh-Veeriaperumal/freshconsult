class AddIndexTimeZoneOnAccounts < ActiveRecord::Migration
  def self.up
  	Lhm.change_table :accounts, :atomic_switch => true do |m|
  		m.add_index :time_zone
    end
  end

  def self.down
  	Lhm.change_table :accounts, :atomic_switch => true do |m|
  		m.remove_index :time_zone
    end
  end
end
