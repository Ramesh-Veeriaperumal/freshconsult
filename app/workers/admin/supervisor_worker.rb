module Admin
  class SupervisorWorker < BaseWorker
    include Redis::RedisKeys
    include Redis::OthersRedis
    include SchedulerSemaphoreMethods
    include AutomationRuleHelper

    sidekiq_options :queue => :supervisor, :retry => 0, :failures => :exhausted
    SUPERVISOR_ERROR = 'SUPERVISOR_EXECUTION_FAILED'.freeze
    TICKET_SAVE_ERROR = 'TICKET_SAVE_FAILED'.freeze

    def perform
      schedule_error = false
      execute_on_db {
        account = Account.current
        return unless account.supervisor_enabled?
        supervisor_rules = account.supervisor_rules
        return unless supervisor_rules.count > 0 
        start_time = Time.now.utc
        rule_type = VAConfig::RULES_BY_ID[VAConfig::RULES[:supervisor]]
        account_negatable_columns = ::VAConfig.negatable_columns(account)
        supervisor_tickets_limit = get_others_redis_key(SUPERVISOR_TICKETS_LIMIT).to_i unless account.whitelist_supervisor_sla_limitation_enabled?
        # SUPERVISOR_TICKETS_LIMIT redis key holds the max number of tickets that can be pick in a single rake job
        # To bypass this max limit check, use 'whitelist_supervisor_sla_limitation' launch party feature
        rule_ids_with_exec_count = {}
        supervisor_rules.each do |rule|
          begin
            rule_start_time = Time.now.utc
            conditions = []
            log_info(account.id, rule.id) {
              conditions = rule.filter_query
            }
            next if conditions.empty?
            negate_conditions = [""]
            negate_conditions = rule.negation_query(account_negatable_columns)
            joins = rule.get_joins(["#{conditions[0]} #{negate_conditions[0]}"])
            tickets_count = 0
            ticket_ids = []
            account.tickets.where(negate_conditions).where(conditions).updated_in(1.month.ago)
                   .visible.joins(joins).readonly(false).preload(:schema_less_ticket).find_each do |ticket|
              next if ticket.service_task?
              tickets_count +=  1
              rule_ids_with_exec_count[rule.id] = tickets_count
              if supervisor_tickets_limit && (tickets_count > supervisor_tickets_limit)
                log_info(account.id, rule.id, ticket.id) {
                  Va::Logger::Automation.log("SUPERVISOR: Tickets limit exceeded, exceeded_ticket_id=#{ticket.id}", true)
                }
                break
              end
              begin
                next if ticket.sent_for_enrichment?
                execute_actions(rule, ticket)
              rescue Exception => e
                schedule_error = true
                log_info(account.id, rule.id, ticket.id) { Va::Logger::Automation.log_error(TICKET_SAVE_ERROR, e) }
                NewRelic::Agent.notice_error(e,{:description => "Error while executing supervisor rule for a tkt :: #{ticket.id} :: account :: #{account.id}" })
                next
              ensure
                ticket_ids.push(ticket.display_id)
                Va::Logger::Automation.unset_thread_variables
              end
            end
            rule_end_time = Time.now.utc
            rule_total_time = (rule_end_time - rule_start_time )
            log_format = logging_format(account, ticket_ids, rule, rule_total_time, conditions, negate_conditions, joins)
            custom_logger.info "#{log_format}" unless custom_logger.nil?
            log_info(account.id, rule.id) {
              Va::Logger::Automation.log("conditions=#{conditions.inspect}, \
              negate_conditons=#{negate_conditions.inspect}, joins=#{joins.inspect}, tickets=#{ticket_ids.inspect}", true)
              Va::Logger::Automation.log_execution_and_time(rule_total_time, ticket_ids.size, rule_type, rule_start_time, rule_end_time)
            }
          rescue Exception => e
            log_info(account.id, rule.id) { Va::Logger::Automation.log_error(SUPERVISOR_ERROR, e) }
            NewRelic::Agent.notice_error(e)
          rescue
            log_info(account.id, rule.id) { Va::Logger::Automation.log_error(SUPERVISOR_ERROR, nil) }
          end
        end
        update_ticket_execute_count(rule_ids_with_exec_count) if rule_ids_with_exec_count.present?
        end_time = Time.now.utc
        total_time = end_time - start_time
        log_info(account.id) { 
          Va::Logger::Automation.log_execution_and_time(total_time, supervisor_rules.size, rule_type, start_time, end_time) 
        }
      }
      ensure
        del_scheduler_semaphore(Account.current.id, self.class.name) unless schedule_error
        Account.reset_current_account
        Va::Logger::Automation.unset_thread_variables
    end

    private

      def log_file
        @log_file_path ||= "#{Rails.root}/log/supervisor.log"
      end

      def execute_actions(rule, ticket, skip_manual_publish = false)
        execute_on_db("run_on_master") do
          rule.trigger_actions ticket

          subscription_changed = (rule.contains_add_watcher_action? && ticket.subscriptions.present?)
          properties_changed = ticket.properties_updated?
          # Note: if ticket has watcher and rule contains add watcher action, it will execute below method.
          properties_changed ||= subscription_changed
          ticket.schema_less_ticket.retry_supervisor_action = true if Account.current.retry_ticket_supervisor_actions_enabled?
          ticket.save_ticket! if properties_changed || ticket.enqueue_va_actions.present?
          if !properties_changed && rule.contains_send_email_action? && !skip_manual_publish
            ticket.manual_publish(['update', RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY], [:update, { system_changes: ticket.system_changes.dup }])
          end
        end
      rescue LockVersion::Utility::TicketParallelUpdateException => e
        Va::Logger::Automation.log(e.message, true)
        Tickets::RetryTicketSupervisorActionsWorker.perform_async(rule_id: rule.id, ticket_id: ticket.id) if Account.current.retry_ticket_supervisor_actions_enabled?
      end

      def logging_format(account,ticket_ids,rule,rule_total_time, conditions, negate_conditions, joins)
        "account_id=#{account.id}, account_name=#{account.name}, fullname=#{account.full_domain}, 
        tickets_count=#{ticket_ids.length}, time_taken=#{rule_total_time}, rule_name=#{rule.name}, 
        rule_id=#{rule.id}, host_name=#{Socket.gethostname}, conditions=#{conditions.inspect}, 
        negate_conditons=#{negate_conditions.inspect}, joins=#{joins.inspect}, 
        tickets=#{ticket_ids.inspect}".squish
      end

      def log_info(account_id, rule_id=nil, ticket_id=nil)
        Va::Logger::Automation.set_thread_variables(account_id, ticket_id, nil, rule_id)
        yield if block_given?
        Va::Logger::Automation.unset_thread_variables
      end
  end
end
