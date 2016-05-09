class AddToggleAvailabilityToGroups < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end
  
  def up
    Lhm.change_table :groups, :atomic_switch => true do |m|
      m.add_column :toggle_availability, "tinyint(1) DEFAULT 0"
    end
  end

  def down
    Lhm.change_table :groups, :atomic_switch => true do |m|
      m.remove_column :toggle_availability
    end
  end
end