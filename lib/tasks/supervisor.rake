#Rake for Supervisor's rule cron job
namespace :supervisor do
  task :run => :environment do
    puts "Supervisor rule check called at #{Time.zone.now}."
    
    Account.all.each do |account|
      account.supervisor_rules.each do |rule|
        conditions = rule.filter_query
        next if conditions.empty?
        
        tickets = account.tickets.updated_in(1.month.ago).visible.find( :all, 
          :joins => "inner join helpdesk_ticket_states on helpdesk_tickets.id = 
          helpdesk_ticket_states.ticket_id inner join users on helpdesk_tickets.requester_id = 
          users.id left join customers on users.customer_id=customers.id", :conditions => 
          conditions )
          
        tickets.each do |ticket| 
          rule.trigger_actions ticket
          ticket.save!
        end
      end
    end
  end
end
