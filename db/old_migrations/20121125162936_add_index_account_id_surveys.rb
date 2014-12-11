class AddIndexAccountIdSurveys < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		CREATE INDEX `index_account_id_on_surrveys` ON surveys (`account_id`)
  	SQL
  end

  def self.down
  	execute <<-SQL
			DROP INDEX `index_account_id_on_surrveys` ON surveys
  	SQL
  end
end
