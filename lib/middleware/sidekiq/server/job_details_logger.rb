module Middleware
  module Sidekiq
    module Server
      class JobDetailsLogger
        def call(_worker, msg, _queue)
          msg['pickup_time']   = Time.now.to_i - msg['enqueued_at'].to_i
          msg['enqueue_time']  = msg['created_at'].to_i - msg['enqueued_at'].to_i
          elapsed              = Benchmark.realtime { yield }
          msg['response_time'] = elapsed
          log_details(msg.symbolize_keys)
        end

        def log_details(msg)
          init_logger
          log_info = log_format(msg)
          @@sidekiq_bb.info log_info.to_s
        end

        def log_format(msg)
          "worker_class=#{msg[:class]}, queue_name=#{msg[:queue]}, jobid=#{msg[:jid]}, account_id=#{msg[:account_id]},"\
            " response_time=#{msg[:response_time]}, enqueued_at = #{msg[:enqueued_at]}, pickup_time = #{msg[:pickup_time]},"\
            " classification = #{msg[:original_queue]}, enqueue_time = #{msg[:enqueue_time]}"
        rescue StandardError => e
          NewRelic::Agent.notice_error(e, custom_params: { description: "Error occoured while capturing controller logs for #{msg}" })
        end

        def init_logger
          @@sidekiq_bb ||= CustomLogger.new("#{Rails.root}/log/sidekiq_bb.log")
        end
      end
    end
  end
end
