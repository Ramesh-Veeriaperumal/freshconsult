# frozen_string_literal: true

class WebhookV2Worker < WebhookV1Worker
  include TenantRateLimiter::Worker
  sidekiq_options queue: 'account_webhook_worker'

  def perform(args)
    args.symbolize_keys!
    Va::Logger::Automation.set_thread_variables(args[:account_id], args[:ticket_id], nil, args[:rule_id])
    Va::Logger::Automation.log "WEBHOOK::V2: TRIGGERED, info=#{args.inspect}", true
    if args[:webhook_validation_enabled] && !valid_webhook_url?(args[:params]['domain'])
      Va::Logger::Automation.log "WEBHOOK::V2: Validation Fails for URL = #{args[:params]['domain']}", true
      return
    end
    @response = HttpRequestProxy.new.fetch_using_req_params(
      args[:params].symbolize_keys,
      args[:auth_header].symbolize_keys,
      args[:custom_headers]
    )
    Va::Logger::Automation.log "WEBHOOK::V2: response=#{@response[:status]}"

    response_status = @response[:status]

    if response_status == REDIRECTION
      Va::Logger::Automation.log 'WEBHOOK::V2: REDIRECTED, will not be re-enqueued and pursued'
    else
      raise TenantRateLimiter::Errors::JobFailure, @response unless SUCCESS.include?(response_status)
    end
  ensure
    Va::Logger::Automation.unset_thread_variables
  end

  class << self
    include TenantRateLimiter::Worker
    include Admin::AutomationConstants

    DEFAULT_WEBHOOK_LIMIT = 1_000
    DROP_AFTER = 86_400
    RETRY_LIMIT = 3
    ACCOUNT_JOB_PARAMS = [:account_id, :webhook_limit].freeze
    TENANT_CLASS = 'Account'
    ERROR_NOTIFICATION_TIMEOUT = 1.hour

    def iterable_options(args = {})
      {
        type: 'redis_sorted_set',
        rate_limit: args[:webhook_limit] || DEFAULT_WEBHOOK_LIMIT,
        tenant_id: args[:account_id],
        retry: RETRY_LIMIT,
        event_timestamp_key: :webhook_created_at,
        worker_name: self.name,
        account_job_params: ACCOUNT_JOB_PARAMS
      }
    end

    def notify_job_drop(webhook_args)
      key = format(WEBHOOK_DROP_NOTIFY, account_id: webhook_args[:account_id])
      count = increment_others_redis(key)
      if count == 1
        Va::Logger::Automation.log "WEBHOOK::V2: DROPPED, created_time=#{Time.at(webhook_args[:webhook_created_at]).utc}", true
        set_others_redis_expiry(key, DROP_AFTER)
        Sharding.select_shard_of(webhook_args[:account_id]) do
          account = Account.find(webhook_args[:account_id]).make_current
          email_list = Account.current.account_managers.map(&:email)
          UserNotifier.send_email_to_group(:notify_webhook_drop, email_list, account)
          webhook_args[:error_type] = Admin::AutomationConstants::WEBHOOK_ERROR_TYPES[:dropoff]
          CentralPublish::CRECentralWorker.perform_async(webhook_args, CentralPublish::CRECentralUtil::CRE_PAYLOAD_TYPES[:webhook_error]) if Account.current.cre_account_enabled?
        end
      end
    end

    def tenant_key(tenant_id)
      format(ACCOUNT_WEBHOOK_JOBS, account_id: tenant_id)
    end

    def retry_exhausted(args)
      Rails.logger.debug "WEBHOOK::V2: FAILED, created_time=#{Time.at(args[:webhook_created_at]).utc}"
      notify_failure(args)
    end

    def log_retry(delay, retry_count)
      Rails.logger.debug "WEBHOOK::V2: RETRY, perform_in=#{delay}, retry_count=#{retry_count}"
    end

    def rate_limit_exceeded_callback(args)
      Rails.logger.debug "WEBHOOK::V2: RATELIMIT EXCEEDED for account #{args[:account_id]}"
      raise_notification(args)
      notify_cre_webhook_limit(args, false)
    end

    def tenant_upper_threshold(rate_limit)
      rate_limit * 26
    end

    def tenant_class
      TENANT_CLASS
    end

    def reset_metrics(args)
      notify_cre_webhook_limit(args, true)
    end

    private

      def notify_failure(args)
        error_notification_key = error_notification_redis_key(args[:account_id], args[:rule_id])
        return if redis_key_exists?(error_notification_key)

        executing_rule = nil
        Sharding.select_shard_of(args[:account_id]) do
          Account.find(args[:account_id]).make_current
          executing_rule = VaRule.find_by_id(args[:rule_id])
          args[:error_type] = WEBHOOK_ERROR_TYPES[:failure]
          CentralPublish::CRECentralWorker.perform_async(args, CentralPublish::CRECentralUtil::CRE_PAYLOAD_TYPES[:webhook_error]) if Account.current.cre_account_enabled?
          return if executing_rule.blank?

          set_others_redis_key(error_notification_key, true, ERROR_NOTIFICATION_TIMEOUT)

          if executing_rule.observer_rule? || executing_rule.dispatchr_rule?
            send_failure_email(args[:params]['domain'], executing_rule)
          elsif executing_rule.api_webhook_rule?
            disable_rule(executing_rule)
          end
        end
      end

      def error_notification_redis_key(account_id, rule_id)
        format(WEBHOOK_ERROR_NOTIFICATION, account_id: account_id, rule_id: rule_id)
      end

      def rule_details(executing_rule)
        {
          name: executing_rule.name,
          path: executing_rule.rule_path,
          type: 'Automation'
        }
      end

      def send_failure_email(domain, executing_rule)
        UserNotifier.send_email_to_group(
          :notify_webhook_failure,
          Account.current.account_managers.map(&:email),
          Account.current,
          rule_details(executing_rule),
          domain
        )
      end

      def disable_rule(rule)
        rule.active = false
        rule.save!
      end

      def raise_notification(args)
        notification_topic = SNS['dev_ops_notification_topic']
        subject = "Webhook Throttler limit exceed for Account ID : #{args[:account_id]}"
        options = { account_id: args[:account_id], environment: Rails.env }
        DevNotification.publish(notification_topic, subject, options.to_json)
      end

      def notify_cre_webhook_limit(webhook_args, reset_metric)
        Sharding.select_shard_of(webhook_args[:account_id]) do
          Account.find(webhook_args[:account_id]).make_current
          webhook_args[:error_type] = Admin::AutomationConstants::WEBHOOK_ERROR_TYPES[:rate_limit]
          webhook_args[:reset_metric] = reset_metric
          CentralPublish::CRECentralWorker.perform_async(webhook_args, CentralPublish::CRECentralUtil::CRE_PAYLOAD_TYPES[:webhook_error]) if Account.current.cre_account_enabled?
        end
      end
  end
end
