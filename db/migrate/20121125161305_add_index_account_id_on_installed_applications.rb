class AddIndexAccountIdOnInstalledApplications < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		CREATE INDEX `index_account_id_on_installed_applications` ON installed_applications (`account_id`)
  	SQL
  end

  def self.down
  	execute <<-SQL
  		DROP INDEX `index_account_id_on_installed_applications` ON installed_applications
  	SQL
  end
end
