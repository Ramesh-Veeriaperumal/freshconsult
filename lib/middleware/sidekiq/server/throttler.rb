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

            if ((Time.now.utc.to_f - webhook_args['webhook_created_at']) > DROP_AFTER)
              notify_webhook_drop(webhook_args)
              return
            end
            
            rate_limit = RateLimit.new(worker, webhook_args, queue, @options)

            rate_limit.within_bounds do
              yield
            end

            rate_limit.exceeded do |delay|
              worker.class.perform_in(delay, webhook_args)
            end

            rate_limit.execute
          else
            yield
          end
        end

        def notify_webhook_drop(webhook_args)
          key = WEBHOOK_DROP_NOTIFY % {:account_id => webhook_args['account_id']}
          count = increment_others_redis(key)
          if count == 1
            set_others_redis_expiry(key, DROP_AFTER)
            Sharding.select_shard_of(webhook_args['account_id']) do
              account = Account.find(webhook_args['account_id']).make_current
              email_list =  Account.current.account_managers.map { |admin| admin.email }.join(",")
              UserNotifier.send_later(:notify_webhook_drop,
                account,
                email_list
              )
            end
          end
        end

      end
    end
  end
end