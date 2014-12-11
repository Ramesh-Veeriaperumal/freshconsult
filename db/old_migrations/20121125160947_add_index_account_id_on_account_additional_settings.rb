class AddIndexAccountIdOnAccountAdditionalSettings < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
  		CREATE INDEX `index_account_id_on_account_additional_settings` ON account_additional_settings (`account_id`)
  	SQL
  end

  def self.down
  	execute <<-SQL
			DROP INDEX `index_account_id_on_account_additional_settings` ON account_additional_settings
  	SQL
  end
end
