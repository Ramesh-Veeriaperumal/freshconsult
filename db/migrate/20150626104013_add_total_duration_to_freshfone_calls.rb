class AddTotalDurationToFreshfoneCalls < ActiveRecord::Migration
  
  shard :all

  def up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :total_duration, "integer(11) DEFAULT NULL"
    end
  end

  def down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_column :total_duration
    end
  end

end
