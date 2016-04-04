class AddHoldQueueToFreshfoneCalls < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :hold_queue, "varchar(50)"
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_column :hold_queue
    end
  end
end
