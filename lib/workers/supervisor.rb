class Workers::Supervisor
  extend Resque::Plugins::Retry
  @queue = 'Supervisor_worker'

  @retry_limit = 3
  @retry_delay = 60*2

  def self.perform(account_id)
    account = Account.find(account_id)
    account.make_current
    account.supervisor_rules.each do |rule|
      begin
        conditions = rule.filter_query
        next if conditions.empty?
      
        tickets = account.tickets.updated_in(1.month.ago).visible.find( :all, 
          :joins => %(inner join helpdesk_schema_less_tickets on helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id 
            and helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id 
            inner join helpdesk_ticket_states on helpdesk_tickets.id = 
            helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = 
            helpdesk_ticket_states.account_id inner join users on 
            helpdesk_tickets.requester_id = users.id  and users.account_id = 
            helpdesk_tickets.account_id  left join customers on users.customer_id = 
            customers.id left join flexifields on helpdesk_tickets.id = 
            flexifields.flexifield_set_id  and helpdesk_tickets.account_id = 
            flexifields.account_id and flexifields.flexifield_set_type = 'Helpdesk::Ticket'), 
          :conditions => conditions )
        tickets.each do |ticket| 
          rule.trigger_actions ticket
          ticket.save!
        end
      rescue => exc
      end
    end
    Account.reset_current_account 
  end
end