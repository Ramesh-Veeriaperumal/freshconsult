class AddBusinessHourCallToFreshfoneCalls < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :business_hour_call, "tinyint(1) DEFAULT 0"
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_column :business_hour_call
    end
  end
end
