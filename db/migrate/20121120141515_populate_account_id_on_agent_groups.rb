class PopulateAccountIdOnAgentGroups < ActiveRecord::Migration
  def self.up
  	execute("update agent_groups inner join users on agent_groups.user_id=users.id set agent_groups.account_id=users.account_id")
  end

  def self.down
  	execute("update agent_groups set account_id=NULL")
  end
end
