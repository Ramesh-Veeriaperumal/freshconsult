module Middleware
  module Sidekiq
    module Server
      class Logs
        def call(_worker, msg, _queue)
          queue_name = msg['queue']
          logger_level = fetch_logger_level_for_sidekiq_queue(queue_name)
          ActiveRecord::Base.logger.level = logger_level
          ::NewRelic::Agent.add_custom_attributes(appVersion: ENV['APP_VERSION'])
          yield
        end

        def fetch_logger_level_for_sidekiq_queue(queue_name)
          members = Rails.cache.fetch('INFO_LEVEL_LOGGER_SIDEKIQ_QUEUES', expires_in: 5.minutes) do
            $redis_others.smembers('INFO_LEVEL_LOGGER_SIDEKIQ_QUEUES_LIST')
          end

          members.include?(queue_name) ? Logger::INFO : Logger::DEBUG
        rescue StandardError => e
          Rails.logger.info "Error in fetching info level sidekiq queues #{e.message}"
          Logger::DEBUG
        end
      end
    end
  end
end
