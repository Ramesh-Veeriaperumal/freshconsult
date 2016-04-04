class AddLastActiveAtToAgents < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :agents, :atomic_switch => true do |t|
      t.add_column :last_active_at, :datetime
    end
  end

  def down
    Lhm.change_table :agents, :atomic_switch => true do |t|
      t.remove_column :last_active_at
    end
  end
end
