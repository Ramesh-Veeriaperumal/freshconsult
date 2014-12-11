class AddIndexAccountIdAndUserIdOnAgents < ActiveRecord::Migration
  def self.up
  	execute("CREATE INDEX `index_agents_on_account_id_and_user_id` ON agents (`account_id`,`user_id`)")
  end

  def self.down
  	execute("DROP INDEX `index_agents_on_account_id_and_user_id` ON agents")
  end
end
