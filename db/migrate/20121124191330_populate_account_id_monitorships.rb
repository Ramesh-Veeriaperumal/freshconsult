class PopulateAccountIdMonitorships < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
			UPDATE monitorships INNER JOIN users ON monitorships.user_id = users.id 
			SET monitorships.account_id = users.account_id
  	SQL
  end

  def self.down
  	execute <<-SQL
			UPDATE monitorships SET account_id = NULL
  	SQL
  end
end
