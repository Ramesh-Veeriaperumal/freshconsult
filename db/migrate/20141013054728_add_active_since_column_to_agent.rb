class AddActiveSinceColumnToAgent < ActiveRecord::Migration
  shard :all
  def self.up
  	Lhm.change_table :agents, :atomic_switch => true do |m|
      m.add_column :active_since, "datetime DEFAULT NULL"
    end
  end

  def self.down
  	 Lhm.change_table :agents, :atomic_switch => true do |m|
      m.remove_column :active_since
    end
  end
end
