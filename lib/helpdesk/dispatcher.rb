  class Helpdesk::Dispatcher

    include RoundRobinCapping::Methods
    include TicketPropertiesSuggester::Util
    include AutomationRuleHelper
    
    #including Redis keys for notify_cc - will be removed later
    include Redis::RedisKeys
    include Redis::OthersRedis

    DISPATCHER_ERROR = 'DISPATCHER_EXECUTION_FAILED'.freeze
    ROUNDROBIN_ERROR = 'ROUND_ROBIN_FAILED'.freeze
    TICKET_MODEL = 'Helpdesk::Ticket'.freeze
    UPDATE = 'update'.freeze

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
      Va::Logger::Automation.log("Triggering Dispatcher, job_id=#{job_id}, job_queue=#{job_queue}", true)
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
      @ticket.prime_ticket_args = params
      Va::Logger::Automation.set_thread_variables(@account.id, params['ticket_id'], params['user_id'])
      Va::Logger::Automation.log("user_nil=#{@user.nil?}, ticket_nil=#{@ticket.nil?}", true) if @user.nil? || @ticket.nil?
    end

    def execute
      Time.use_zone(@account.time_zone) {
        execute_rules unless @is_webhook
        unless skip_rr?
          round_robin unless @ticket.spam? || @ticket.deleted?
          @ticket.sbrr_fresh_ticket = true
        end
        @ticket.skip_ocr_sync = true
        if @sla_on_background && @ticket.is_in_same_sla_state?(@sla_attributes)
          @ticket.update_sla = true
          @ticket.sla_calculation_time = @sla_calculation_time
        end
        @ticket.save
        @ticket.sync_task_changes_to_ocr(nil) if Account.current.omni_channel_routing_enabled?
        notify_cc_recipients
        @ticket.autoreply
        @ticket.va_rules_after_save_actions.each do |action|
          klass = action[:klass].constantize
          klass.safe_send(action[:method], action[:args])
        end
      }
      # To send bot response for tickets created via email
      ::Freddy::AgentSuggestArticles.perform_async(ticket_id: @ticket.id) if source_email?
      dispatcher_set_priority = Thread.current[:dispatcher_set_priority].present? ? true : false
      ::Freddy::TicketPropertiesSuggesterWorker.perform_async(ticket_id: @ticket.id, action: 'predict', dispatcher_set_priority: dispatcher_set_priority) if trigger_ticket_properties_suggester?
      push_payload_to_ml(@ticket, :ml_ticket_update) if bot_features_enabled?
    rescue Exception => e
      Va::Logger::Automation.log_error(DISPATCHER_ERROR, e)
      NewRelic::Agent.notice_error(e)
      raise e
    ensure
      Va::Logger::Automation.unset_thread_variables
    end

    private

      def bot_features_enabled?
        @account.email_bot_enabled? || @account.triage_enabled?
      end

      def push_payload_to_ml(object, payload_type)
        conn = CentralPublisher.configuration.central_connection
        rt_measure = Benchmark.measure do
          @ml_response = conn.post { |r| r.body = request_body(object, payload_type) }
        end
        Rails.logger.info("Time Taken for request :: Account id : #{Account.current.id} :: Ticket id : #{@ticket.id} Time taken : #{rt_measure.real} Response status : #{@ml_response.status}")
      rescue StandardError => e
        Rails.logger.error("Central publish ml_ticket_update failed Account id : #{Account.current.id} :: Ticket id : #{@ticket.id} serv request:: #{e.message}")
        NewRelic::Agent.notice_error(e, custom_params: { account_id: Account.current.id, ticket_id: @ticket.id, job_id: Thread.current[:message_uuid].last, description: "Error while publishing requester ml_ticket_update : #{e.message}"})
      end

      def request_body(object, payload_type)
        {
          account_id: Account.current.id.to_s,
          organisation_id: Account.current.organisation.try(:organisation_id).try(:to_s),
          organisation_user_id: org_user_id,
          pod: PodConfig['CURRENT_POD'],
          region: PodConfig['CURRENT_REGION'],
          payload_version: CentralPublisher.generate_payload_version(TICKET_MODEL),
          payload_type: payload_type,
          payload: training_payload(object, payload_type)
        }.to_json
      end

      def org_user_id
        @user.freshid_authorization.uid if @user && @user.try(:helpdesk_agent) && @user.freshid_authorization
      end

      def training_payload(object, payload_type)
        object.central_payload_type = payload_type
        actor_epoch = Time.zone.now.to_f
        {
          model: TICKET_MODEL,
          action: UPDATE,
          actor: @user.try(:central_publish_payload),
          action_epoch: actor_epoch,
          uuid: CentralPublisher.generate_uuid,
          event_info: object.event_info(:update),
          account_full_domain: Account.current.full_domain,
          event_timestamp: Time.at(actor_epoch).utc.iso8601(3),
          product_push_timestamp: Time.now.utc.iso8601(3),
          model_properties: object.central_publish_payload.merge(additional_properties),
          associations: object.central_publish_associations
        }
      end

      def additional_properties
        additional_properties = {}
        email_configs = Account.current.email_configs_from_cache
        additional_properties[:reply_email] = email_configs[@ticket.email_config_id] if email_configs[@ticket.email_config_id].present?
        additional_properties[:header_info] = @ticket.header_info if @ticket.header_info.present?
        additional_properties
      end

    def source_email?
      if @ticket.spam_or_deleted?
        Rails.logger.info "Ticket #{@ticket.id} is either spammed or deleted before getting ML response"
        return false
      else
        (@account.support_bot_configured? && (@ticket.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:email] && @account.bot_email_channel_enabled? && @ticket.portal.bot.try(:email_channel)) || (@account.bot_agent_response_enabled? && !@ticket.bot?)) || @account.agent_articles_suggest_enabled? || @account.email_articles_suggest_enabled?
      end
    end

    def notify_cc_recipients
      if @ticket.cc_email_hash.present? && @ticket.cc_email_hash[:cc_emails].present? && get_others_redis_key("NOTIFY_CC_ADDED_VIA_DISPATCHER").present?
        Helpdesk::TicketNotifier.send_later(:send_cc_email, @ticket, nil, {:cc_emails => @ticket.cc_email_hash[:cc_emails].to_a })
      end
    end

    def execute_rules
      start_time = Time.now.utc
      evaluate_on = @ticket
      total_rules = 0 # used if cascade_dispatcher feature not present
      rule_ids_with_exec_count = {}
      Va::Logger::Automation.log('Dispatcher execution starts', true)
      rules.each do |vr|
        begin
          Va::Logger::Automation.set_rule_id(vr.id)
          evaluate_on = nil
          time = Benchmark.realtime {
            evaluate_on = vr.check_rule_conditions(@ticket, nil, @user)
          }
          rule_ids_with_exec_count[vr.id] = 1 if evaluate_on.present?
          Va::Logger::Automation.log_execution_and_time(time, (evaluate_on.present? ? 1 : 0), rule_type)
        rescue Exception => e
          Va::Logger::Automation.log_error(DISPATCHER_ERROR, e)
        end
        total_rules += 1
        next if @account.cascade_dispatcher_enabled?
        if evaluate_on.present?
          update_ticket_execute_count(rule_ids_with_exec_count) if rule_ids_with_exec_count.present? # when cascade_dispatcher is disabled
          log_total_execution_info(total_rules, rule_type, start_time, Time.now.utc)
          return
        end
      end
      update_ticket_execute_count(rule_ids_with_exec_count) if rule_ids_with_exec_count.present? # when cascade_dispatcher is enabled
      log_total_execution_info(total_rules, rule_type, start_time, Time.now.utc)
    end

    def round_robin
      begin
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
      rescue Exception => e
        Va::Logger::Automation.log_error(ROUNDROBIN_ERROR, e)
      end
    end

    def log_total_execution_info(total_tickets, rule_type, start_time, end_time)
      total_time = end_time - start_time
      Va::Logger::Automation.unset_rule_id
      Va::Logger::Automation.log_execution_and_time(total_time, total_tickets, rule_type, start_time, end_time)
    rescue Exception => e
      Va::Logger::Automation.log_error("Error in log_total_execution_info", e)
    end

    # Adding these methods since service_task_dispatcher.rb inherits this class
    def rules
      @account.va_rules
    end

    def rule_type
      VAConfig::RULES_BY_ID[VAConfig::RULES[:dispatcher]]
    end

    def skip_rr?
      false
    end
  end
