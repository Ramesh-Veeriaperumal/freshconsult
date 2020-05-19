class AddAgentTypeToRoles < ActiveRecord::Migration
	shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :roles, :atomic_switch => true do |m|
      m.add_column :agent_type, "integer DEFAULT 1"
    end
  end

  def down
    Lhm.change_table :roles, :atomic_switch => true do |m|
      m.remove_column :agent_type
    end
  end
end
