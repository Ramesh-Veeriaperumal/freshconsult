class PopulateAccountIdOnHelpdeskReminder < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
			UPDATE helpdesk_reminders INNER JOIN users ON helpdesk_reminders.user_id = users.id 
			SET helpdesk_reminders.account_id = users.account_id
  	SQL
  end

  def self.down
  	execute <<-SQL
  		UPDATE helpdesk_reminders SET account_id = NULL
  	SQL
  end
end
