class WebhookV1Worker < ::BaseWorker
  include Sidekiq::Worker
  include Redis::RedisKeys
  include Redis::OthersRedis
  
  SUCCESS     = 200..299
  REDIRECTION = 300..399
  ERROR_NOTIFICATION_TIMEOUT = 1.hour
  RETRY_LIMIT = 3

  sidekiq_options :queue => 'webhook_v1_worker', :retry => 0, :dead => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @response = HttpRequestProxy.new.fetch_using_req_params(
      args[:params].symbolize_keys,
      args[:auth_header].symbolize_keys,
      args[:custom_headers]
    )
    case @response[:status]
    when SUCCESS
    when REDIRECTION
      Rails.logger.debug "Redirected : Won't be re-enqueued and pursued"
    else
      if args[:webhook_retry_count].to_i < RETRY_LIMIT
        args[:webhook_retry_count] = args[:webhook_retry_count].to_i + 1
        delay = next_retry_in(args[:webhook_retry_count]) 
        self.class.perform_in(delay, args)
      else
        notify_failure(args)
      end
    end
  rescue => e
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description =>"Sidekiq Observer Webhook execution error",
        :args => args
      }})
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
        :type => executing_rule.rule_type_desc.to_s
      }
    end

    def notify_failure(args)
      error_notification_key = error_notification_redis_key(args[:account_id], args[:rule_id])
      return if redis_key_exists?(error_notification_key)
      executing_rule = nil
      Sharding.select_shard_of(args[:account_id]) do
        current_account = Account.find(args[:account_id]).make_current
        executing_rule = VaRule.find_by_id(args[:rule_id])

        return unless executing_rule.present?

        set_others_redis_key( error_notification_key, true, ERROR_NOTIFICATION_TIMEOUT)

        if (executing_rule.observer_rule? || executing_rule.dispatchr_rule?)
          email_list =  Account.current.account_managers.map { |admin|
            admin.email
          }.join(",")
          UserNotifier.send_later(
            :notify_webhook_failure,
            current_account,
            email_list, 
            rule_details(executing_rule), 
            args[:params]["domain"]
          )
          Rails.logger.info "Webhook retry failure for account id - #{args[:account_id]} ::: Rule - #{rule_details(executing_rule).inspect} ::: Error - #{@response[:status]}: #{@response[:text]}"
        elsif executing_rule.api_webhook_rule?
          executing_rule.active = false
          executing_rule.save!
        end
      end
    end
end
