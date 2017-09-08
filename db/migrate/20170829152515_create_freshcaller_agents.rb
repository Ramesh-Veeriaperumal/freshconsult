class CreateFreshcallerAgents < ActiveRecord::Migration
  shard :all
  def up
    create_table :freshcaller_agents do |t|
      t.references :account, :limit => 8
      t.references :agent, :limit => 8
      t.integer :fc_agent_id, :limit => 8
      t.boolean :fc_enabled, :default => false
      t.timestamps
    end

    add_index :freshcaller_agents, [:account_id, :agent_id]
  end

  def down
    drop_table :freshcaller_agents
  end
end
