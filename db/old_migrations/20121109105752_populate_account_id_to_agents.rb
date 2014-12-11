class PopulateAccountIdToAgents < ActiveRecord::Migration
  def self.up
  	execute("UPDATE agents INNER JOIN users ON agents.user_id=users.id set agents.account_id=users.account_id")
  end

  def self.down
  	execute("UPDATE agents SET account_id=null")
  end
end
