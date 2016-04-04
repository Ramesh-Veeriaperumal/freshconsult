class AddRingingTimeToFreshfoneNumbers < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :ringing_time, "int(11) DEFAULT 30"
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :ringing_time
    end
  end
end
