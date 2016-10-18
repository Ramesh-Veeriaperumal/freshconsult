module Admin::Sla::Escalation
  class Base < BaseWorker

    
    sidekiq_options :queue => :sla, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform
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
      overdue_tickets = escalate_overdue(sla_default,sla_rule_based,"resolution")
      overdue_tickets_end_time=Time.now.utc
      overdue_tickets_time_taken=overdue_tickets_end_time - overdue_tickets_start_time
      total_tickets += overdue_tickets

      #Response overdue
      froverdue_tickets_start_time=Time.now.utc
      froverdue_tickets = escalate_overdue(sla_default,sla_rule_based,"response")
      froverdue_tickets_end_time=Time.now.utc
      froverdue_tickets_time_taken=froverdue_tickets_end_time - froverdue_tickets_start_time
      total_tickets += froverdue_tickets

      #group escalate
      group_escalate

      log_format=logging_format(account,overdue_tickets,overdue_tickets_time_taken,froverdue_tickets,froverdue_tickets_time_taken)
      custom_logger.info "#{log_format}" unless custom_logger.nil?
    ensure
      Account.reset_current_account
    end

    protected

      def escalate_overdue(sla_default, sla_rule_based, overdue_type)
        account = Account.current
        execute_on_db do
          overdue_tickets_count = 0
          overdue_tickets = account.tickets.unresolved.visible.
                            send("#{overdue_type}_sla", account, Time.zone.now.to_s(:db)).
                            updated_in(2.month.ago)
          overdue_tickets.find_each do |ticket|
            overdue_tickets_count += 1
            sla_policy = sla_rule_based[ticket.sla_policy_id] || sla_default
            execute_on_db("run_on_master") do
              sla_policy.send("escalate_#{overdue_type}_overdue", ticket)
            end
          end
          overdue_tickets_count
        end
      end

      def group_escalate
        ##Tickets left unassigned in group
        account = Account.current
        execute_on_db do
          tickets_unpicked = account.tickets.unresolved.visible.
                             group_escalate_sla(Time.zone.now.to_s(:db)).
                             updated_in(2.month.ago)
          tickets_unpicked.find_each do |gr_ticket|
            send_email(gr_ticket, gr_ticket.group.escalate, EmailNotification::TICKET_UNATTENDED_IN_GROUP) unless gr_ticket.group.escalate.nil?
            execute_on_db("run_on_master") do
              gr_ticket.ticket_states.update_attribute(:group_escalated , true)
            end
          end
        end
      end

      def log_file
        @log_file_path ||= "#{Rails.root}/log/sla.log"      
      end 
      
      def logging_format(account, overdue_tickets, overdue_tickets_time_taken, froverdue_tickets, froverdue_tickets_time_taken)
        "account_id=#{account.id}, account_name=#{account.name}, fullname=#{account.full_domain}, overdue_tickets=#{overdue_tickets}, overdue_tickets_time_taken=#{overdue_tickets_time_taken}, froverdue_tickets=#{froverdue_tickets}, froverdue_tickets_time_taken=#{froverdue_tickets_time_taken}, total_tickets=#{overdue_tickets + froverdue_tickets} total_time_taken=#{froverdue_tickets_time_taken + overdue_tickets_time_taken} , host_name=#{Socket.gethostname} "    
      end 

      def send_email(ticket, agent, n_type)
        SlaNotifier.send_later(:agent_escalation, ticket, agent, n_type)
      end      
  end
end