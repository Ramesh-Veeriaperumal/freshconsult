#Rake tasks for SLA escalation..
namespace :sla do
  desc 'Check for SLA violation and trigger emails..'
  task :escalate => :environment do
    puts "SLA Escalation task initialized at #{Time.zone.now}"
    accounts = Account.active_accounts
    accounts.each do |account|     
    
    overdue_tickets = account.tickets.visible.find(:all, :readonly => false, :conditions =>['due_by <=? AND isescalated=? AND status=?', Time.zone.now.to_s(:db),false,Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open]] )
    puts "Number of overdues are #{overdue_tickets.size}"
    overdue_tickets.each do |ticket|      
      sla_policy_id = nil
      unless ticket.requester.customer.nil?     
        sla_policy_id = ticket.requester.customer.sla_policy_id     
      end      
      sla_policy_id = Helpdesk::SlaPolicy.find_by_account_id_and_is_default(ticket.account_id, true) if sla_policy_id.nil?     
      sla_detail = Helpdesk::SlaDetail.find(:first , :conditions =>{:sla_policy_id =>sla_policy_id, :priority =>ticket.priority})
           
      unless sla_detail.escalateto.nil?
        agent = User.find(sla_detail.escalateto)                 
        send_email(ticket, agent, EmailNotification::RESOLUTION_TIME_SLA_VIOLATION)
      end
        ticket.update_attribute(:isescalated , true)
     end
    
    froverdue_tickets = account.tickets.visible.find(:all, :joins => :ticket_states , :readonly => false , :conditions =>['frDueBy <=? AND fr_escalated=? AND status=? AND helpdesk_ticket_states.first_response_time IS ?', Time.zone.now.to_s(:db),false,Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],nil] )
    puts "Number of first response overdues are #{froverdue_tickets.size}"
    froverdue_tickets.each do |fr_ticket|
      
      fr_sla_policy_id = nil
      unless fr_ticket.requester.customer.nil?     
        fr_sla_policy_id = fr_ticket.requester.customer.sla_policy_id     
      end      
      fr_sla_policy_id = Helpdesk::SlaPolicy.find_by_account_id_and_is_default(fr_ticket.account_id, true) if fr_sla_policy_id.nil?     
      fr_sla_detail = Helpdesk::SlaDetail.find(:first , :conditions =>{:sla_policy_id =>fr_sla_policy_id, :priority =>fr_ticket.priority})
      
      unless fr_sla_detail.escalateto.nil?
        fr_agent = User.find(fr_sla_detail.escalateto)  
        send_email(fr_ticket, fr_agent, EmailNotification::FIRST_RESPONSE_SLA_VIOLATION)
      end
        fr_ticket.update_attribute(:fr_escalated , true)   
        #If there is no email-id /agent still escalted will show as true. This is to avoid huge sending if somebody changes the config
    end
    
    
    ##Tickets left unassigned in group
    
    tickets_unpicked = account.tickets.visible.find(:all, :joins => [:ticket_states,:group] , :readonly => false , :conditions =>['DATE_ADD(helpdesk_tickets.created_at, INTERVAL groups.assign_time SECOND)  <=? AND group_escalated=? AND status=? AND helpdesk_ticket_states.first_assigned_at IS ?', Time.zone.now.to_s(:db),false,Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],nil] )
    puts "Number of un attended tickets are #{tickets_unpicked.size}"
    tickets_unpicked.each do |gr_ticket| 
      send_email(gr_ticket, gr_ticket.group.escalate, EmailNotification::TICKET_UNATTENDED_IN_GROUP) unless gr_ticket.group.escalate.nil?
      gr_ticket.ticket_states.update_attribute(:group_escalated , true)
    end
    end
    puts "SLA Escalation task completed.."
  end
end
#SLA ends here

def send_email(ticket, agent, n_type)
  e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
  return unless e_notification.agent_notification
  
  email_body = Liquid::Template.parse(e_notification.agent_template).render(
                                'agent' => agent, 'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
  SlaNotifier.deliver_escalation(ticket, agent, :email_body => email_body, :subject => e_notification.ticket_subject(ticket))
end
