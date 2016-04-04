class AddIndexToAddresses < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :addresses, :atomic_switch => true do |t|
      t.add_index [:addressable_id]
    end
  end

  def down
    Lhm.change_table :addresses, :atomic_switch => true do |t|
      t.remove_index [:addressable_id]
    end
  end
  
end
