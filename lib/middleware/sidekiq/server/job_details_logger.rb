module Middleware
  module Sidekiq
    module Server
      class JobDetailsLogger

        def call(worker, msg, queue)
          elapsed = Benchmark.realtime { yield }
          msg['response_time'] = elapsed
          msg['pickup_time'] = Time.now.to_i - msg["enqueued_at"].to_i
          log_details(msg.symbolize_keys)
        end

        def log_details(msg)
          init_logger
          log_info = log_format(msg)
          @@sidekiq_bb.info "#{log_info}"
        end

        def log_format(msg)
          begin
            "worker_class=#{msg[:class]}, queue_name=#{msg[:queue]}, account_id=#{msg[:account_id]}, response_time=#{msg[:response_time]}, enqueued_at = #{msg[:enqueued_at]}, pickup_time = #{msg[:pickup_time]}"
          rescue Exception => e
            NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing controller logs for #{msg}"}})
          end
        end

        def init_logger
          @@sidekiq_bb ||= CustomLogger.new("#{Rails.root}/log/sidekiq_bb.log")
        end
      end
    end
  end
end
