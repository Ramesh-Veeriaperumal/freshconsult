class Workers::Sla 
  extend Resque::AroundPerform 

 
  
 class PremiumSLA < Workers::Sla 
  @queue = 'premium_sla_worker'

  def self.perform(args)
    run
  end
 end

 class AccountSLA < Workers::Sla 
  @queue = 'sla_worker'

  def self.perform(args)
    run
  end
 end

 def self.run
    account = Account.current
    db_name = account.premium? ? "run_on_master" : "run_on_slave"
    sla_default = account.sla_policies.default.first
    sla_rule_based = account.sla_policies.rule_based.active.inject({}) { |sp_hash, sp| 
                                                                      sp_hash[sp.id] = sp; sp_hash}

    overdue_tickets =  execute_on_db(db_name) {
                        account.tickets.visible.updated_in(2.month.ago).find(:all, 
                            :readonly => false, 
                            :conditions =>['due_by <=? AND isescalated=? AND status IN (?)',
                             Time.zone.now.to_s(:db),false, 
                             Helpdesk::TicketStatus::donot_stop_sla_statuses(account)] )
                      }
    overdue_tickets.each do |ticket|  
      sla_policy = sla_rule_based[ticket.sla_policy_id] || sla_default
      sla_policy.escalate_resolution_overdue ticket #escalate_resolution_overdue
    end
    
    froverdue_tickets = execute_on_db(db_name) {
                        account.tickets.updated_in(2.month.ago).visible.find(:all, 
                            :joins => "inner join helpdesk_ticket_states 
                                     on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id 
                                     and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id" , 
                            :readonly => false , 
                            :conditions =>['frDueBy <=? AND fr_escalated=? AND status IN (?) AND 
                                                helpdesk_ticket_states.first_response_time IS ?', 
                          Time.zone.now.to_s(:db),false,
                          Helpdesk::TicketStatus::donot_stop_sla_statuses(account),nil] )
                       }
    froverdue_tickets.each do |fr_ticket|
      fr_sla_policy = sla_rule_based[fr_ticket.sla_policy_id] || sla_default
      fr_sla_policy.escalate_response_overdue fr_ticket
      #If there is no email-id /agent still escalted will show as true. This is to avoid huge sending if 
      # somebody changes the config.
    end
    
    ##Tickets left unassigned in group
    
    tickets_unpicked =  execute_on_db(db_name) {
                          account.tickets.updated_in(2.month.ago).visible.find(:all, 
                            :joins => "inner join helpdesk_ticket_states 
                            on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id 
                            and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id 
                            inner join groups on groups.id = helpdesk_tickets.group_id" ,
                          :readonly => false , 
                           :conditions =>['DATE_ADD(helpdesk_tickets.created_at, INTERVAL groups.assign_time SECOND)  <=? AND 
                            group_escalated=? AND status=? AND helpdesk_ticket_states.first_assigned_at IS ?', 
                            Time.zone.now.to_s(:db),false,Helpdesk::Ticketfields::TicketStatus::OPEN,nil] )
                        }
    tickets_unpicked.each do |gr_ticket| 
      send_email(gr_ticket, gr_ticket.group.escalate, EmailNotification::TICKET_UNATTENDED_IN_GROUP) unless gr_ticket.group.escalate.nil?
      gr_ticket.ticket_states.update_attribute(:group_escalated , true)
    end
  end

  def self.execute_on_db(db_name)
    Sharding.send(db_name.to_sym) do
      yield
    end
  end


  def self.send_email(ticket, agent, n_type)
    e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
    return unless e_notification.agent_notification
    agent.make_current
    email_subject = Liquid::Template.parse(e_notification.agent_subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
    email_body = Liquid::Template.parse(e_notification.formatted_agent_template).render(
                                'agent' => agent, 'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
    SlaNotifier.deliver_escalation(ticket, [agent], :email_body => email_body, :subject => email_subject)
    User.reset_current
  end
end