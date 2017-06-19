module Middleware
  module Sidekiq
    module Client
      class BelongsToAccount
  
        IGNORE = []

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end

        def call(worker, msg, queue,redis_pool)
          #original queue is used to print in sidekiq_bb.log to see which queue takes more time. We can remove it once its stable
          original_queue = msg['queue']
          msg['queue'] = queue_from_classification(msg['queue'])
          msg['original_queue'] = original_queue
          if !@ignore.include?(worker.to_s)
            msg['account_id'] = ::Account.current.id
            msg['message_uuid'] = Thread.current[:message_uuid]
          end
          yield
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        end

        def queue_from_classification(queue_name)
          #cache locally for 5 mins to avoid redis calls for every push
          #will remove this code once its stable
          members = Rails.cache.fetch("SIDEKIQ_CLASSIFICATION",  expires_in: 5.minutes) do
            $redis_others.smembers("SIDEKIQ_QUEUE_CLASSIFICATION_LIST")
          end
          members.include?(queue_name) ? SIDEKIQ_CLASSIFICATION_MAPPING[queue_name] : queue_name
        end

      end
    end
  end
end
