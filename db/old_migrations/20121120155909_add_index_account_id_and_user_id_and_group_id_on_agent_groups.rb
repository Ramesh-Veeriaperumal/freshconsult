class AddIndexAccountIdAndUserIdAndGroupIdOnAgentGroups < ActiveRecord::Migration
  def self.up
  	execute("CREATE INDEX `index_agent_groups_on_account_id_and_user_id_and_group_id` ON agent_groups (`account_id`,`user_id`,`group_id`)")
  end

  def self.down
  	execute("DROP INDEX `index_agent_groups_on_account_id_and_user_id_and_group_id` ON agent_groups")
  end
end
