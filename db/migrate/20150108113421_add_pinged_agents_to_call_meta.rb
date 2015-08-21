class AddPingedAgentsToCallMeta < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_calls_meta, :atomic_switch => true do |m|
      m.add_column :pinged_agents, :text
      m.add_column :hunt_type, "tinyint(2)"
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls_meta, :atomic_switch => true do |m|
      m.remove_column :pinged_agents
      m.remove_column :hunt_type
    end
  end
end