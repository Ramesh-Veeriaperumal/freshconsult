class PopulateAccountIdTicketTopics < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
			UPDATE ticket_topics INNER JOIN helpdesk_tickets ON ticket_topics.ticket_id = helpdesk_tickets.id 
			SET ticket_topics.account_id = helpdesk_tickets.account_id
  	SQL
  end

  def self.down
  	execute <<-SQL
			UPDATE ticket_topics SET account_id = NULL
  	SQL
  end
end
