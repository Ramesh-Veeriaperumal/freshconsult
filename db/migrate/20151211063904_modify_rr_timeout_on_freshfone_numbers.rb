class ModifyRrTimeoutOnFreshfoneNumbers < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.change_column :rr_timeout, "int(11) DEFAULT 20"
    end
  end

  def down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.change_column :rr_timeout, "int(11) DEFAULT 10"
    end
  end
end
