class AddIndexToMonitorship < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end
  
  def up
    Lhm.change_table :monitorships, :atomic_switch => true do |m|
      m.add_index [:account_id,:monitorable_id,:"monitorable_type(5)"], 'index_on_monitorships_acc_mon_id_and_type'
    end
  end
  
  def down
    Lhm.change_table :monitorships, :atomic_switch => true do |m|
      m.remove_index [:account_id,:monitorable_id,:"monitorable_type(5)"], 'index_on_monitorships_acc_mon_id_and_type'
    end
  end
end