module Middleware
  module Sidekiq
    module Client
      class RouteORDrop
        def call(_worker, msg, _queue, _redis_pool)
          original_queue = msg['queue']
          msg['original_queue'] = original_queue
          msg['queue'] = if msg['rerouted_queue']
                           msg['reroute'] = true
                           msg['rerouted_queue']
                         else
                           queue_from_classification(msg['queue'])
                         end
          yield
        end

        private

          def queue_from_classification(queue_name)
            # cache locally for 5 mins to avoid redis calls for every push
            # will remove this code once its stable
            members = []
            begin
              members = Rails.cache.fetch('SIDEKIQ_CLASSIFICATION', expires_in: 5.minutes) do
                $redis_others.smembers('SIDEKIQ_QUEUE_CLASSIFICATION_LIST')
              end

              dedicated_list = Rails.cache.fetch('DEDICATED_SIDEKIQ_QUEUE', expires_in: 5.minutes) do
                $redis_others.smembers('DEDICATED_SIDEKIQ_QUEUE_LIST')
              end

              if Account.current && dedicated_list.include?(Account.current.id.to_s)
                members.include?(queue_name) ? "#{SIDEKIQ_CLASSIFICATION_MAPPING[queue_name]}_#{Account.current.id}" : queue_name
              else
                members.include?(queue_name) ? SIDEKIQ_CLASSIFICATION_MAPPING[queue_name] : queue_name
              end
            rescue StandardError => e
              Rails.logger.info "Error in fetching classification... #{e.message}"
              members.include?(queue_name) ? SIDEKIQ_CLASSIFICATION_MAPPING[queue_name] : queue_name
            end
          end
      end
    end
  end
end
