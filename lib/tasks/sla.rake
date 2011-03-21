#Rake tasks for SLA escalation..
namespace :sla do
  desc 'Check for SLA violation and trigger emails..'
  task :escalate => :environment do
    puts "SLA Escalation task initialized at #{Time.zone.now}"
    
    overdue_tickets = Helpdesk::Ticket.find(:all, :readonly => false, :conditions =>['due_by <=? AND isescalated=? AND status=?', Time.zone.now.to_s(:db),false,Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open]] )
    puts "Number of overdues are #{overdue_tickets.size}"
    overdue_tickets.each do |ticket|
      escalateto = ticket.account.sla_policies.first.sla_details.find_by_priority(ticket.priority).escalateto
      unless escalateto.nil?
        email = User.find_by_id(escalateto).email                  
        SlaNotifier.deliver_sla_escalation(ticket, email) unless email.nil?
      end
        ticket.update_attribute(:isescalated , true)
     end
    
    froverdue_tickets = Helpdesk::Ticket.find(:all, :joins => :ticket_states , :readonly => false , :conditions =>['frDueBy <=? AND fr_escalated=? AND helpdesk_ticket_states.first_response_time IS ?', Time.now.to_s(:db),false,nil] )
    puts "Number of first response overdues are #{froverdue_tickets.size}"
    froverdue_tickets.each do |fr_ticket|
      fr_escalateto = fr_ticket.account.sla_policies.first.sla_details.find_by_priority(fr_ticket.priority).escalateto
      unless fr_escalateto.nil?
        fr_email = User.find_by_id(fr_escalateto).email  
        SlaNotifier.deliver_fr_sla_escalation(fr_ticket,fr_email) unless fr_email.nil?
      end
        fr_ticket.update_attribute(:fr_escalated , true)   
        #If there is no email-id /agent still escalted will show as true. This is to avoid huge sending if somebody changes the config
    end
    puts "SLA Escalation task completed.."
  end
end
#SLA ends here
