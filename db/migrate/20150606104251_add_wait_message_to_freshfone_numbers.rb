class AddWaitMessageToFreshfoneNumbers < ActiveRecord::Migration
  shard :none
  def up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :wait_message, :text
    end
  end

  def down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :wait_message
    end
  end
end
