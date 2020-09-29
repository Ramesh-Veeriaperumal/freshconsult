class WebhookV1Worker < ::BaseWorker
  include Sidekiq::Worker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Admin::Automation::WebhookValidations
  include Admin::AutomationConstants
  
  SUCCESS     = 200..299
  REDIRECTION = 300..399
  ERROR_NOTIFICATION_TIMEOUT = 1.hour
  RETRY_LIMIT = 3

  sidekiq_options :queue => 'webhook_v1_worker', :retry => 0, :dead => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    Va::Logger::Automation.set_thread_variables(args[:account_id], args[:ticket_id], nil, args[:rule_id])
    Va::Logger::Automation.log("WEBHOOK: TRIGGERED, info=#{args.inspect}", true)
    if args[:webhook_validation_enabled] && !valid_webhook_url?(args[:params]["domain"])
      Va::Logger::Automation.log("WEBHOOK: Validation Fails for URL = #{args[:params]['domain']}", true)
      return 
    end
    @response = HttpRequestProxy.new.fetch_using_req_params(
      args[:params].symbolize_keys,
      args[:auth_header].symbolize_keys,
      args[:custom_headers]
    )
    Va::Logger::Automation.log("WEBHOOK: response=#{@response[:status]}")
    response_status = @response[:status]
    case response_status
    when SUCCESS
    when REDIRECTION
      Va::Logger::Automation.log 'WEBHOOK: REDIRECTED, will not be re-enqueued and pursued'
    else
      webhook_retry_count = args[:webhook_retry_count].to_i
      if webhook_retry_count < RETRY_LIMIT
        webhook_retry_count += 1
        delay = next_retry_in(webhook_retry_count)
        Va::Logger::Automation.log "WEBHOOK: RETRY, perform_in=#{delay}, retry_count=#{webhook_retry_count}"
        args[:webhook_retry_count] = webhook_retry_count
        self.class.perform_in(delay, args)
      else
        Va::Logger::Automation.log "WEBHOOK: FAILED, response_status=#{response_status}, response_text=#{@response[:text]}, created_time=#{Time.at(args[:webhook_created_at]).utc}"
        notify_failure(args)
      end
    end
  rescue => e
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description =>"Sidekiq Observer Webhook execution error",
        :args => args
      }})
  ensure
    Va::Logger::Automation.unset_thread_variables
  end

  private

    def next_retry_in(count)
      [
        5.minutes, 
        30.minutes, 
        1.hour
      ][count-1]
    end

    def error_notification_redis_key(account_id, rule_id)
      WEBHOOK_ERROR_NOTIFICATION % { :account_id => account_id, :rule_id => rule_id }
    end

    def rule_details executing_rule
      {
        :name => executing_rule.name,
        :path => executing_rule.rule_path,
        :type => 'Automation'
      }
    end

    def notify_failure(args)
      error_notification_key = error_notification_redis_key(args[:account_id], args[:rule_id])
      return if redis_key_exists?(error_notification_key)
      executing_rule = nil
      Sharding.select_shard_of(args[:account_id]) do
        current_account = Account.find(args[:account_id]).make_current
        executing_rule = VaRule.find_by_id(args[:rule_id])
        args[:error_type] = WEBHOOK_ERROR_TYPES[:failure]
        CentralPublish::CRECentralWorker.perform_async(args, CentralPublish::CRECentralUtil::CRE_PAYLOAD_TYPES[:webhook_error]) if Account.current.cre_account_enabled?
        return unless executing_rule.present?

        set_others_redis_key( error_notification_key, true, ERROR_NOTIFICATION_TIMEOUT)

        if (executing_rule.observer_rule? || executing_rule.dispatchr_rule?)
          email_list =  Account.current.account_managers.map { |admin|
            admin.email
          }.join(",")
          UserNotifier.send_email_to_group(
            :notify_webhook_failure,
            email_list.split(','),
            current_account, 
            rule_details(executing_rule), 
            args[:params]["domain"]
          )
        elsif executing_rule.api_webhook_rule?
          executing_rule.active = false
          executing_rule.save!
        end
      end
    end
end
