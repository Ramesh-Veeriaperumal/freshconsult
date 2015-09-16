class AddHoldMessageToFreshfoneNumbers < ActiveRecord::Migration
  shard :none
  def up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :hold_message, :text
    end
  end

  def down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :hold_message
    end
  end
end
