class AddRoundRobinColumnToFreshfoneNumber < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :hunt_type, "int(11) DEFAULT 1"
      m.add_column :rr_timeout, "int(11) DEFAULT 10"
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :hunt_type
      m.remove_column :rr_timeout
    end
  end
end
