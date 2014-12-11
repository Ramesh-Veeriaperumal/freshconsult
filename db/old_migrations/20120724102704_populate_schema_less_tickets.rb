class PopulateSchemaLessTickets < ActiveRecord::Migration
  def self.up
		Account.find(:all, :conditions => ["subscriptions.next_renewal_at > '2012-07-20 00:00:00'"], :joins => [:subscription], :order => "accounts.id").each do |account|
		  execute("insert ignore into helpdesk_schema_less_tickets(account_id,ticket_id,product_id) select account_id,id,email_config_id from helpdesk_tickets where account_id=#{account.id}")
		  execute("update helpdesk_schema_less_tickets set product_id = NULL where product_id = #{account.primary_email_config.id}") 

		  Helpdesk::Ticket.find_in_batches(:batch_size => 1000, :conditions => ["helpdesk_tickets.account_id = #{account.id}"]) do |tickets|
		    tickets.each {|ticket| ticket.schema_less_ticket.update_attributes(:to_emails => ticket.to_emails) }
		  end 
		end
  end

  def self.down
  end
end
