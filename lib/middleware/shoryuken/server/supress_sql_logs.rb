module Middleware
  module Shoryuken
    module Server
      class SupressSqlLogs
        def call(worker_instance, _queue, _sqs_msg, _body)
          worker_name = worker_instance.class.name
          logger_level = fetch_logger_level_for_shoryuken_worker(worker_name)
          ActiveRecord::Base.logger.level = logger_level
          yield
        end

        def fetch_logger_level_for_shoryuken_worker(worker_name)
          members = Rails.cache.fetch('INFO_LEVEL_LOGGER_SHORYUKEN_WORKERS', expires_in: 5.minutes) do
            $redis_others.smembers('INFO_LEVEL_LOGGER_SHORYUKEN_WORKERS_LIST')
          end

          members.include?(worker_name) ? Logger::INFO : Logger::DEBUG
        rescue StandardError => e
          Rails.logger.info "Error in fetching info level shoryuken workers #{e.message}"
          Logger::DEBUG
        end
      end
    end
  end
end
