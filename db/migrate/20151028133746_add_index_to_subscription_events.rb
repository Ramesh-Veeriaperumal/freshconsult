class AddIndexToSubscriptionEvents < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :subscription_events, :atomic_switch => true do |t|
      t.add_index [:created_at]
    end
  end

  def down
    Lhm.change_table :subscription_events, :atomic_switch => true do |t|
      t.remove_index [:created_at]
    end
  end
  
end
