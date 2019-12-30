class ChangeDeletedToBooleanInAgentType < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :agent_types, atomic_switch: true do |t|
      t.change_column :deleted, 'tinyint(1) DEFAULT 0'
    end
  end

  def down
    Lhm.change_table :agent_types, atomic_switch: true do |t|
      t.change_column :deleted, 'int(11) DEFAULT 0'
    end
  end
end
