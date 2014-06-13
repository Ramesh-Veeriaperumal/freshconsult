module Admin
  class SlaWorker < BaseWorker

    
    sidekiq_options :queue => :sla, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(msg)
      total_tickets = 0
      account = Account.current
      sla_default = execute_on_db { account.sla_policies.default.first }
      sla_rule_based = execute_on_db do 
        account.sla_policies.rule_based.active.inject({}) do |sp_hash, sp| 
          sp_hash[sp.id] = sp; sp_hash
        end
      end
      
      #Resolution overdue
      overdue_tickets_start_time=Time.now.utc
      overdue_tickets = resolution_overdue(sla_default,sla_rule_based)
      overdue_tickets_end_time=Time.now.utc
      overdue_tickets_time_taken=overdue_tickets_end_time - overdue_tickets_start_time
      total_tickets += overdue_tickets.length

      #Response overdue
      froverdue_tickets_start_time=Time.now.utc
      froverdue_tickets = response_overdue(sla_default,sla_rule_based)
      froverdue_tickets_end_time=Time.now.utc
      froverdue_tickets_time_taken=froverdue_tickets_end_time - froverdue_tickets_start_time
      total_tickets += froverdue_tickets.length

      #group escalate
      group_escalate

      log_format=logging_format(account,overdue_tickets,overdue_tickets_time_taken,froverdue_tickets,froverdue_tickets_time_taken)
      custom_logger.info "#{log_format}" unless custom_logger.nil?
    ensure
      Account.reset_current_account
    end

    protected
    
      def log_file
        @log_file_path ||= "#{Rails.root}/log/sla.log"      
      end 
      
      def logging_format(account,overdue_tickets,overdue_tickets_time_taken,froverdue_tickets,froverdue_tickets_time_taken)
        "account_id=#{account.id}, account_name=#{account.name}, fullname=#{account.full_domain}, overdue_tickets=#{overdue_tickets.size}, overdue_tickets_time_taken=#{overdue_tickets_time_taken}, froverdue_tickets=#{froverdue_tickets.size}, froverdue_tickets_time_taken=#{froverdue_tickets_time_taken}, total_tickets=#{overdue_tickets.size + froverdue_tickets.size} total_time_taken=#{froverdue_tickets_time_taken + overdue_tickets_time_taken} , host_name=#{Socket.gethostname} "    
      end 

      def send_email(ticket, agent, n_type)
        e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
        return unless e_notification.agent_notification
        agent.make_current
        email_subject = Liquid::Template.parse(e_notification.agent_subject_template).render(
                                    'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
        email_body = Liquid::Template.parse(e_notification.formatted_agent_template).render(
                                    'agent' => agent, 'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
        SlaNotifier.deliver_escalation(ticket, [agent], :email_body => email_body, :subject => email_subject)
      ensure
        User.reset_current
      end

      def resolution_overdue(sla_default, sla_rule_based)
        account = Account.current
        overdue_tickets =  execute_on_db {
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
        overdue_tickets
      end

      def response_overdue(sla_default, sla_rule_based)
        account = Account.current
        froverdue_tickets = execute_on_db {
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
        froverdue_tickets
      end

      def group_escalate
        ##Tickets left unassigned in group
        account = Account.current
        tickets_unpicked =  execute_on_db {
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
  end
end