module CronWebhooks
  class RedisMaintenance < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_redis_maintenance, retry: 0, dead: true, failures: :exhausted

    def perform(args)
      perform_block(args) do
        safe_send(@args[:task_name])
      end
    end

    private

      def redis_maintenance_set_timestamp
        REDIS_UNIQUE_CONNECTION_OBJECTS.each do |con|
          con.perform_redis_op('set', Redis::RedisKeys::TIMESTAMP_REFERENCE, Time.now.to_i)
        end
      end

      def redis_maintenance_slowlog_mailer
        slowlog = []
        REDIS_UNIQUE_CONNECTION_OBJECTS.each do |con|
          # Move to Lua script.
          # Config response format => ["slowlog-max-len", "128"]
          len = con.perform_redis_op('config', 'get', 'slowlog-max-len')
          result = con.multi do |m|
            m.perform_redis_op('slowlog', 'get', len[1])
            m.perform_redis_op('slowlog', 'reset')
          end
          slowlog += result[0]
        end
        csv = Redis::SlowlogParser.parse(slowlog) if slowlog.any?
        FreshopsMailer.send_redis_slowlog(csv)
      end
  end
end
