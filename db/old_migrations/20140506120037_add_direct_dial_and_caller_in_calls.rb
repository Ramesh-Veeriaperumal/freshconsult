class AddDirectDialAndCallerInCalls < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :direct_dial_number, "varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL"
      m.add_column :caller_number_id, :bigint
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_column :direct_dial_number
      m.remove_column :caller_number_id
    end
  end
end
