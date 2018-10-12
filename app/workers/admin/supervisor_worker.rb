module Admin
  class SupervisorWorker < BaseWorker
    include Redis::RedisKeys
    include Redis::OthersRedis

    sidekiq_options :queue => :supervisor, :retry => 0, :backtrace => true, :failures => :exhausted
    SUPERVISOR_ERROR = 'SUPERVISOR_EXECUTION_FAILED'.freeze
    TICKET_SAVE_ERROR = 'TICKET_SAVE_FAILED'.freeze

    def perform
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
            .visible.joins(joins).readonly(false).find_each do |ticket|
              tickets_count +=  1
              Va::Logger::Automation.set_thread_variables(account.id, ticket.id, nil, rule.id)
              if supervisor_tickets_limit && (tickets_count > supervisor_tickets_limit)
                Va::Logger::Automation.log "SUPERVISOR: Tickets limit exceeded, exceeded_ticket_id=#{ticket.id}"
                break
              end
              begin
                next if ticket.sent_for_enrichment?
                execute_on_db("run_on_master") do
                  rule.trigger_actions ticket
                  subscription_changed = (rule.contains_add_watcher_action? && ticket.subscriptions.present?)
                  properties_changed = ticket.properties_updated?
                  Va::Logger::Automation.log "Ticket property changed=#{properties_changed}, Ticket subscriptions changed=#{subscription_changed}"
                  # Note: if ticket has watcher and rule contains add watcher action, it will execute below method.
                  properties_changed ||= subscription_changed
                  ticket.save_ticket! if properties_changed
                  if !properties_changed && rule.contains_send_email_action?
                    ticket.manual_publish(['update', RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY], [:update, { system_changes: ticket.system_changes.dup }])
                  end
                end
              rescue Exception => e
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
              Va::Logger::Automation.log "conditions=#{conditions.inspect}, 
              negate_conditons=#{negate_conditions.inspect}, joins=#{joins.inspect}, tickets=#{ticket_ids.inspect}"
              Va::Logger::Automation.log_execution_and_time(rule_total_time, ticket_ids.size, rule_type, rule_start_time, rule_end_time)
            }
          rescue Exception => e
            log_info(account.id, rule.id) { Va::Logger::Automation.log_error(SUPERVISOR_ERROR, e) }
            NewRelic::Agent.notice_error(e)
          rescue
            log_info(account.id, rule.id) { Va::Logger::Automation.log_error(SUPERVISOR_ERROR, nil) }
          end
        end
        end_time = Time.now.utc
        total_time = end_time - start_time
        log_info(account.id) { 
          Va::Logger::Automation.log_execution_and_time(total_time, supervisor_rules.size, rule_type, start_time, end_time) 
        }
      }
      ensure
        Account.reset_current_account
        Va::Logger::Automation.unset_thread_variables
    end

    private

      def log_file
        @log_file_path ||= "#{Rails.root}/log/supervisor.log"
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
