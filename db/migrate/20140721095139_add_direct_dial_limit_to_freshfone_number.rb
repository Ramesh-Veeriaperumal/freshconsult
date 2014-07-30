class AddDirectDialLimitToFreshfoneNumber < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :direct_dial_limit, "int(11) DEFAULT 1"
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :direct_dial_limit
    end
  end
end
