  class Helpdesk::Dispatcher

    include RoundRobinCapping::Methods
    
    #including Redis keys for notify_cc - will be removed later
    include Redis::RedisKeys
    include Redis::OthersRedis

    DISPATCHER_ERROR = 'DISPATCHER_EXECUTION_FAILED'.freeze

    def self.enqueue(ticket, user_id)
      #based on account subscription, enqueue into proper queue
      account = Account.current
      job_queues = ["Premium" , "Free", "Trial" , "Active"]
      args = {:ticket_id => ticket.id, :user_id => user_id, :is_webhook => ticket.freshdesk_webhook?, :sla_args => {:sla_on_background => ticket.sla_on_background, :sla_state_attributes => ticket.sla_state_attributes, :sla_calculation_time => ticket.sla_calculation_time.to_i}}
      job_queue = "spam" if account.spam_email?
      job_queue ||= "premium" if account.premium_email?
      job_queue ||= account.subscription.state
      job_queue.capitalize!

      #queue 'Spam' and everything else into the dispatcher queue
      job_queue = "Worker" if ( !job_queues.include?(job_queue) || Rails.env.development? || Rails.env.test? )
      job_id = "Admin::Dispatcher::#{job_queue}".constantize.perform_async(args)
      Va::Logger::Automation.log "Triggering Dispatcher, job_id=#{job_id}, job_queue=#{job_queue}"
    rescue Exception => e   
      NewRelic::Agent.notice_error(e)
    end

    def initialize params
      @account           = Account.current
      @user              = params['user_id'].blank? ? nil : @account.all_users.find(params['user_id'])
      @ticket            = @account.tickets.find(params['ticket_id'])
      @is_webhook        = params['is_webhook']
      @sla_on_background = params['sla_args'] && params['sla_args']['sla_on_background']
      @sla_attributes    = params['sla_args'] && params['sla_args']['sla_state_attributes']
      @sla_calculation_time = params['sla_args'] && params['sla_args']['sla_calculation_time']
      Va::Logger::Automation.set_thread_variables(@account.id, params['ticket_id'], params['user_id'])
      Va::Logger::Automation.log("user_nil=#{@user.nil?}, ticket_nil=#{@ticket.nil?}") if (@user.nil? || @ticket.nil?)
    end

    def execute
      Time.use_zone(@account.time_zone) {
        execute_rules unless @is_webhook
        round_robin unless @ticket.spam? || @ticket.deleted?
        @ticket.sbrr_fresh_ticket = true
        if @sla_on_background && @ticket.is_in_same_sla_state?(@sla_attributes)
          @ticket.update_sla = true
          @ticket.sla_calculation_time = @sla_calculation_time
        end
        @ticket.save
        notify_cc_recipients
        @ticket.autoreply
        @ticket.va_rules_after_save_actions.each do |action|
          klass = action[:klass].constantize
          klass.safe_send(action[:method], action[:args])
        end
      }
    rescue Exception => e
      Va::Logger::Automation.log_error(DISPATCHER_ERROR, e)
      NewRelic::Agent.notice_error(e)
      raise e
    ensure
      Va::Logger::Automation.log "********* END OF DISPATCHER *********"
      Va::Logger::Automation.unset_thread_variables
    end

    private

    def notify_cc_recipients
      if @ticket.cc_email_hash.present? && @ticket.cc_email_hash[:cc_emails].present? && get_others_redis_key("NOTIFY_CC_ADDED_VIA_DISPATCHER").present?
        Helpdesk::TicketNotifier.send_later(:send_cc_email, @ticket, nil, {:cc_emails => @ticket.cc_email_hash[:cc_emails].to_a })
      end
    end

    def execute_rules
      start_time = Time.now.utc
      rule_type = VAConfig::RULES_BY_ID[VAConfig::RULES[:dispatcher]]
      evaluate_on = @ticket
      total_rules = 0 # used if cascade_dispatcher feature not present
      @account.va_rules.each do |vr|
        begin
          Va::Logger::Automation.set_rule_id(vr.id)
          evaluate_on = nil
          time = Benchmark.realtime {
            evaluate_on = vr.pass_through(@ticket,nil,@user)
          }
          Va::Logger::Automation.log_execution_and_time(time, (evaluate_on.present? ? 1 : 0), rule_type)
        rescue Exception => e
          Va::Logger::Automation.log_error(DISPATCHER_ERROR, e)
        end
        total_rules += 1
        next if @account.features?(:cascade_dispatchr)
        if evaluate_on.present?
          log_total_execution_info(total_rules, rule_type, start_time, Time.now.utc)
          return
        end
      end
      log_total_execution_info(total_rules, rule_type, start_time, Time.now.utc)
    end

    def round_robin
      #Ticket already has an agent assigned to it or doesn't have a group
      group = @ticket.group
      return if group.nil?
      if @ticket.responder_id
        @ticket.update_capping_on_create
        return
      end
      if group.round_robin_enabled?
        @ticket.assign_agent_via_round_robin
      end
    end

    def log_total_execution_info(total_tickets, rule_type, start_time, end_time)
      total_time = end_time - start_time
      Va::Logger::Automation.unset_rule_id
      Va::Logger::Automation.log_execution_and_time(total_time, total_tickets, rule_type, start_time, end_time)
    end
end
