class PopulateAccountIdOnHelpdeskSubscriptions < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
			UPDATE helpdesk_subscriptions INNER JOIN users ON helpdesk_subscriptions.user_id = users.id 
			SET helpdesk_subscriptions.account_id = users.account_id
  	SQL
  end

  def self.down
  	execute <<-SQL
			UPDATE helpdesk_subscriptions SET helpdesk_subscriptions.account_id = NULL
  	SQL
  end
end
