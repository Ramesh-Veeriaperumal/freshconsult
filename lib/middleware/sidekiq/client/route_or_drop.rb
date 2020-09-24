module Middleware
  module Sidekiq
    module Client
      class RouteORDrop
        include Middleware::Sidekiq::PublishToCentralUtil
        COMMON = :common
        def call(_worker, msg, _queue, _redis_pool)
          original_queue = msg['queue']
          msg['original_queue'] = original_queue
          msg['queue'] = if msg['rerouted_queue']
                           msg['reroute'] = true
                           msg['rerouted_queue']
                         else
                           queue_from_classification(msg['queue'])
                         end
          publish_data_to_central(msg, PAYLOAD_TYPE[:job_enqueued]) if publish_to_central?(msg['original_queue'])
          yield
        end

        private

          def queue_from_classification(queue_name)
            # cache locally for 5 mins to avoid redis calls for every push
            # will remove this code once its stable
            begin
              dedicated_list = Rails.cache.fetch('DEDICATED_SIDEKIQ_QUEUE', expires_in: 5.minutes) do
                $redis_others.smembers('DEDICATED_SIDEKIQ_QUEUE_LIST')
              end

              if Account.current && dedicated_list.include?(Account.current.id.to_s)
                SIDEKIQ_CLASSIFICATION_MAPPING_NEW.key?(queue_name) ? "#{SIDEKIQ_CLASSIFICATION_MAPPING_NEW[queue_name]}_#{Account.current.id}" : COMMON
              else
                SIDEKIQ_CLASSIFICATION_MAPPING_NEW.key?(queue_name) ? SIDEKIQ_CLASSIFICATION_MAPPING_NEW[queue_name] : COMMON
              end
            rescue StandardError => e
              Rails.logger.info "Error in fetching classification... #{e.message}"
              SIDEKIQ_CLASSIFICATION_MAPPING_NEW.key?(queue_name) ? SIDEKIQ_CLASSIFICATION_MAPPING_NEW[queue_name] : COMMON
            end
          end
      end
    end
  end
end
