class AddAgentTypeToAgent < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :agents do |m|
      m.add_column :agent_type, "int"
    end
  end

  def down
   	Lhm.change_table :agents do |m|
      m.remove_column :agent_type
    end
  end
end
