class AddCallInfoToFreshcallerCalls < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :freshcaller_calls, atomic_switch: true do |t|
      t.add_column :call_info, :text
    end
  end

  def down
    Lhm.change_table :freshcaller_calls, atomic_switch: true do |t|
      t.remove_column :call_info
    end
  end
end
