#Rake for Supervisor's rule cron job
namespace :supervisor do
  task :run => :environment do
   unless Rails.env.staging?    
    puts "Supervisor rule check called at #{Time.zone.now}."
    Account.active_accounts.each do |account|
      account.make_current
      account.supervisor_rules.each do |rule|
        begin
          conditions = rule.filter_query
          #puts "Conditions query is #{conditions.inspect}"
          next if conditions.empty?
        
          tickets = account.tickets.updated_in(1.month.ago).visible.find( :all, 
            :joins => %(inner join helpdesk_schema_less_tickets on helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id
              inner join helpdesk_ticket_states on helpdesk_tickets.id = 
              helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = 
              helpdesk_ticket_states.account_id inner join users on 
              helpdesk_tickets.requester_id = users.id  and users.account_id = 
              helpdesk_tickets.account_id  left join customers on users.customer_id = 
              customers.id left join flexifields on helpdesk_tickets.id = 
              flexifields.flexifield_set_id  and helpdesk_tickets.account_id = 
              flexifields.account_id and flexifields.flexifield_set_type = 'Helpdesk::Ticket'), 
            :conditions => conditions )
          puts "conditions :#{conditions.inspect}"
          puts "ticket : #{tickets.inspect}"
          tickets.each do |ticket| 
            rule.trigger_actions ticket
            ticket.save!
          end
        
          #puts "Tickets count #{tickets.count}"
        rescue => exc
          puts "Got some error while running supervisor check with the rule #{rule.id} - #{exc}"
        end
      end
    end
    puts "Supervisor rule check finished at #{Time.zone.now}."
    Account.reset_current_account 
   end
  end
end
