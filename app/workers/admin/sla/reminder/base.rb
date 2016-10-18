module Admin::Sla::Reminder
  class Base < BaseWorker

    sidekiq_options :queue => :sla_reminders, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform

      total_tickets = 0
      account = Account.current

      return if account.nil?
      user_based_sla = execute_on_db { account.sla_policies.active }

      response_reminder_rules = user_based_sla.reject{|e| e.escalations[:reminder_response].nil? }.inject ({}) do |sp_hash, sp|sp_hash[sp.id] = sp; sp_hash end

      resolution_reminder_rules = user_based_sla.reject{|e| e.escalations[:reminder_resolution].nil? }.inject ({}) do |sp_hash, sp|sp_hash[sp.id] = sp; sp_hash end 

      # Response Reminder
      if (!response_reminder_rules.empty? && account.email_notifications.response_sla_reminder.first.agent_notification?)
        response_reminder_start_time = Time.now.utc
        reminder_response_tickets = escalate_reminder(response_reminder_rules, "response")
        response_reminder_time_taken = Time.now.utc - response_reminder_start_time
        total_tickets += reminder_response_tickets
      end

      #Resolution Reminder
      if (!resolution_reminder_rules.empty? && account.email_notifications.resolution_sla_reminder.first.agent_notification?)
        reminder_tickets_start_time = Time.now.utc
        reminder_resolution_tickets = escalate_reminder(resolution_reminder_rules, "resolution")
        reminder_ticket_time_taken = Time.now.utc - reminder_tickets_start_time
        total_tickets += reminder_resolution_tickets
      end

      log_format=logging_format(account,total_tickets,response_reminder_time_taken,reminder_ticket_time_taken)
      custom_logger.info "#{log_format}" unless custom_logger.nil?

    ensure
      Account.reset_current_account
    end

    protected

      def escalate_reminder(sla_rule_based, reminder_type)
        account = Account.current
        reminder_overdue = Time.zone.now +
                           Helpdesk::SlaPolicy::REMINDER_TIME_OPTIONS.first[-1].abs +
                           Helpdesk::SlaPolicy::SLA_WORKER_INTERVAL

        execute_on_db do
          reminder_tickets_count = 0
          reminder_tickets = account.tickets.unresolved.visible.
                             send("#{reminder_type}_sla", account, reminder_overdue.to_s(:db)).
                             send("#{reminder_type}_reminder", sla_rule_based.keys).
                             updated_in(2.month.ago)
          reminder_tickets.find_each do |ticket|
            reminder_tickets_count += 1
            sla_policy = sla_rule_based[ticket.sla_policy_id]
            execute_on_db("run_on_master") do
              sla_policy.send("escalate_#{reminder_type}_reminder", ticket)
            end
          end
          reminder_tickets_count
        end
      end

      def log_file
        @log_file_path ||= "#{Rails.root}/log/sla_reminders.log"      
      end 
      
      def logging_format(account, total_tickets, response_reminder_time_taken, reminder_ticket_time_taken)
        "account_id=#{account.id}, account_name=#{account.name}, fullname=#{account.full_domain}, total_tickets=#{total_tickets}, response_reminder_time_taken=#{response_reminder_time_taken.to_i},  reminder_resolution_time_taken=#{reminder_ticket_time_taken.to_i}, total_time_taken=#{response_reminder_time_taken.to_i + reminder_ticket_time_taken.to_i} , host_name=#{Socket.gethostname} " 
      end 
          
  end
end