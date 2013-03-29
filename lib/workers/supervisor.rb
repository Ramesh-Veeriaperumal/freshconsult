class Workers::Supervisor
  extend Resque::AroundPerform
  

  @queue = 'supervisor_worker'
  
  class PremiumSupervisor
    extend Resque::AroundPerform
    @queue = 'premium_supervisor_worker'

    def self.perform(args)
     Workers::Supervisor.run
    end
  end

  def self.perform(args)
    run
  end

 

  def self.run
    account = Account.current
    return if account.supervisor_rules.count > 0 
      start_time = Time.now.utc
    account.supervisor_rules.each do |rule|
      begin
        conditions = rule.filter_query
        next if conditions.empty?
      
        tickets = Sharding.run_on_slave do
         account.tickets.updated_in(1.month.ago).visible.find( :all, 
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
         end
        tickets.each do |ticket| 
          rule.trigger_actions ticket
          ticket.save!
        end
      rescue Exception => e
        puts "something is wrong: #{e.message}"
      rescue
        puts "something went wrong"
      end
    end
    end_time = Time.now.utc
    if((end_time - start_time) > 250)
      total_time = Time.at(Time.now.utc - start_time).gmtime.strftime('%R:%S')
      puts "Time total time it took to execute the supervisor rules for, #{account.id}, #{account.full_domain}, #{total_time}"
  end
  end
end