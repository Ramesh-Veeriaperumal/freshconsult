module Middleware
  module Sidekiq
    module Server
      class JobDetailsLogger

        def call(worker, msg, queue)
          log_details(msg.symbolize_keys)
          yield
        end

        def log_details(msg)
          init_logger
          log_info = log_format(msg)
          @@sidekiq_bb.info "#{log_info}"
        end

        def log_format(msg)
          "worker_class=#{msg[:class]}, queue_name=#{msg[:queue]}, account_id=#{msg[:account_id]}"
        end

        def init_logger
          @@sidekiq_bb ||= CustomLogger.new("#{Rails.root}/log/sidekiq_bb.log")
        end

      end
    end
  end
end
