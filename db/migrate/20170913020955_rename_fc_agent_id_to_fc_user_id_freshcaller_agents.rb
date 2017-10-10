class RenameFcAgentIdToFcUserIdFreshcallerAgents < ActiveRecord::Migration
  shard :all
  def up
    rename_column :freshcaller_agents, :fc_agent_id, :fc_user_id
  end

  def down
    rename_column :freshcaller_agents, :fc_user_id, :fc_agent_id
  end
end
