module Middleware
  module Sidekiq
    module Server

      class RateLimit
        include Redis::RedisKeys
        include Redis::OthersRedis

        def initialize(worker, payload, queue, options = {})
          @worker = worker
          @payload = payload
          @queue = queue
        end

        def within_bounds(&block)
          @within_bounds = block
        end

        def exceeded(&block)
          @exceeded = block
        end

        def execute
          if exceeded?
            if expires_in >= 0
              limit_exceeded_callback
              @exceeded.call(expires_in)
            end
          else
            @within_bounds.call
          end
        end

        def exceeded?
          get_count > threshold
        end

        def get_count
          count = increment_others_redis(key)
          if count == 1
            set_others_redis_expiry(key, 3600)
          end
          count
        end
        
        def threshold
          @payload['webhook_limit'] || 1000
        end

        def expires_in
          @expires_in ||= get_others_redis_expiry(key)
        end

        def key
          @key ||= WEBHOOK_THROTTLER % {:account_id => @payload['account_id']}
        end

        def limit_exceeded_callback
          limit_exceeded_key = WEBHOOK_THROTTLER_LIMIT_EXCEEDED % {:account_id => @payload['account_id']}
          unless redis_key_exists?(limit_exceeded_key)
            set_others_redis_key(limit_exceeded_key, true, expires_in)
            raise_notification
          end
        end

        def raise_notification
          notification_topic = SNS["dev_ops_notification_topic"]
          subject = "Webhook Throttler limit exceed for Account ID : #{@payload['account_id']}"
          options = { :account_id => @payload['account_id'], :environment => Rails.env }
          DevNotification.publish(notification_topic, subject, options.to_json)
        end

      end

    end
  end
end