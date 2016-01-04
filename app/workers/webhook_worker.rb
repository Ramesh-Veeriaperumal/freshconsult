class WebhookWorker < BaseWorker
  include Sidekiq::Worker
  include Redis::RedisKeys
  include Redis::OthersRedis

  RETRY_LIMIT = 3
  SUCCESS     = 200..299
  REDIRECTION = 300..399
  REQUEST_DEFAULT_TIMEOUT = 30
  ERROR_NOTIFICATION_TIMEOUT = 1.hour

  sidekiq_options :queue => 'webhook_worker',
    :retry => 0,
    :dead => true,
    :failures => :exhausted
  
  def perform(args)
    args.symbolize_keys!
    append_request_timeout(args)
    response = HttpRequestProxy.new.fetch_using_req_params(
      args[:params].symbolize_keys,
      args[:auth_header].symbolize_keys
    )
    case response[:status]
    when SUCCESS
    when REDIRECTION
      Rails.logger.debug "Redirected : Won't be re-enqueued and pursued"
    else

      if args[:retry_count] < RETRY_LIMIT
        args[:retry_count] = args[:retry_count].to_i + 1
        throttler_args = {  
          :args => args, 
          :retry_after => next_retry_in(args[:retry_count]) 
        }
        Throttler::WebhookThrottler.perform_async(throttler_args)
      else
        # error_notification_key = error_notification_redis_key(args[:account_id], args[:rule_id])
        # unless redis_key_exists?(error_notification_key)
        #   set_others_redis_key( error_notification_key, true, ERROR_NOTIFICATION_TIMEOUT)
        #   notify_failure(args)
        # end
      end
    end
  rescue => e
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description =>"Sidekiq Observer Webhook execution error"
      }})
  ensure
    Account.reset_current_account
  end

  def request_timeout
    REQUEST_DEFAULT_TIMEOUT
  end
  private
    def next_retry_in(count)
      [
        5.minutes, 
        30.minutes, 
        1.hour
      ][count-1]
    end

    def append_request_timeout(args)
      args[:params][:timeout] = request_timeout
    end

    def error_notification_redis_key(account_id, rule_id)
      WEBHOOK_ERROR_NOTIFICATION % {
        :account_id => account_id,
        :rule_id => rule_id
      }
    end

    def rule_details executing_rule
      {
        :name => executing_rule.name,
        :path => executing_rule.rule_path,
        :type => executing_rule.rule_type_desc.to_s
      }
    end

    def notify_failure(args)
      executing_rule = nil
      Sharding.select_shard_of(args[:account_id]) do
        current_account = Account.find(args[:account_id]).make_current
        execute_on_db do
          executing_rule = VaRule.find_by_id(args[:rule_id])
          return unless executing_rule.present?
        end
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
      end
    end
end

