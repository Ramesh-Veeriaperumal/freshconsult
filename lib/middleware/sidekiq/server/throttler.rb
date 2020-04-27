module Middleware
  module Sidekiq
    module Server
      class Throttler
        DROP_AFTER = 86400

        include Redis::RedisKeys
        include Redis::OthersRedis

        def initialize(options = {})
          @options = options.dup
          @included = options.fetch(:required_classes, [])
        end

        def call(worker, msg, queue)
          if @included.include?(worker.class.name)
            
            webhook_args = msg['args'][0]

            Va::Logger::Automation.set_thread_variables(webhook_args['account_id'], webhook_args['ticket_id'], nil, webhook_args['rule_id'])
            if ((Time.now.utc.to_f - webhook_args['webhook_created_at']) > DROP_AFTER)
              notify_webhook_drop(webhook_args)
              return
            end
            
            rate_limit = RateLimit.new(worker, webhook_args, queue, @options)
            log_content = "throttler_count=#{rate_limit.throttler_count}, webhook_limit=#{rate_limit.threshold}"
            notify_cre_webhook_limit(webhook_args, true) if rate_limit.get_count == 1

            rate_limit.within_bounds do
              Va::Logger::Automation.log("WEBHOOK: TRIGGERING, #{log_content}", true)
              yield
            end

            rate_limit.exceeded do |delay|
              Va::Logger::Automation.log("WEBHOOK: EXCEEDED, #{log_content}, perform_in=#{delay}", true)
              worker.class.perform_in(delay, webhook_args)
              notify_cre_webhook_limit(webhook_args, false)
            end

            rate_limit.execute
          else
            yield
          end
        ensure
          Va::Logger::Automation.unset_thread_variables
        end

        def notify_webhook_drop(webhook_args)
          key = WEBHOOK_DROP_NOTIFY % {:account_id => webhook_args['account_id']}
          count = increment_others_redis(key)
          if count == 1
            Va::Logger::Automation.log("WEBHOOK: DROPPED, created_time=#{Time.at(webhook_args['webhook_created_at']).utc}", true)
            set_others_redis_expiry(key, DROP_AFTER)
            Sharding.select_shard_of(webhook_args['account_id']) do
              account = Account.find(webhook_args['account_id']).make_current
              email_list =  Account.current.account_managers.map { |admin| admin.email }.join(",")
              UserNotifier.send_email_to_group(:notify_webhook_drop, email_list.split(','),
                account
              )
              webhook_args['error_type'] = Admin::AutomationConstants::WEBHOOK_ERROR_TYPES[:dropoff]
              CentralPublish::CRECentralWorker.perform_async(webhook_args, CentralPublish::CRECentralUtil::CRE_PAYLOAD_TYPES[:webhook_error]) if Account.current.cre_account_enabled?
            end
          end
        end

        def notify_cre_webhook_limit(webhook_args, reset_metric)
          Sharding.select_shard_of(webhook_args['account_id']) do
            Account.find(webhook_args['account_id']).make_current
            webhook_args['error_type'] = Admin::AutomationConstants::WEBHOOK_ERROR_TYPES[:rate_limit]
            webhook_args['reset_metric'] = reset_metric
            CentralPublish::CRECentralWorker.perform_async(webhook_args, CentralPublish::CRECentralUtil::CRE_PAYLOAD_TYPES[:webhook_error]) if Account.current.cre_account_enabled?
            Account.reset_current_account
          end
        end
      end
    end
  end
end
