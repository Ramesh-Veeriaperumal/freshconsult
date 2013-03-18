class AddAccountIdAndSlaPolicyIdIndexOnSlaDetails < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		CREATE INDEX `index_account_id_and_sla_policy_id_on_sla_details` ON 
  					sla_details (account_id, sla_policy_id)
  	SQL
  end

  def self.down
  	execute <<-SQL
  		DROP INDEX `index_account_id_on_installed_applications` ON installed_applications
  	SQL
  end
end
