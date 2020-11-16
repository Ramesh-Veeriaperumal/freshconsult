require 'newrelic_rpm'

module Middleware
  module Shoryuken
    module Server
      class Logs
        include NewRelic::Agent::Instrumentation::ControllerInstrumentation

        def call(worker_instance, _queue, _sqs_msg, _body)
          # Supress SQL logs
          worker_name = worker_instance.class.name
          logger_level = fetch_logger_level_for_shoryuken_worker(worker_name)
          ActiveRecord::Base.logger.level = logger_level
          # Adds release version in newrelic
          ::NewRelic::Agent.add_custom_attributes(appVersion: ENV['APP_VERSION'])
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
