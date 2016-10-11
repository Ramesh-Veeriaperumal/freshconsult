# Override raw_push_without_batch method of Sidekiq pro.
# Sidekiq::Client.reliable_push! for Sidekiq shouldn't be enabled as job will get duplicated, i.e both to redis(when it is reachable) and Shoryuken(SQS))
# Sidekiq client middleware adds necessary payload(account_id, current_user_id) for that worker class,
#  we wait for the job push to error out in case Redis is not reachable 
#  and push the payload to Shoryuken.

module Sidekiq::MethodOverride
  class Sidekiq::Client
    private
      def raw_push_without_batch(payloads)
        begin
          @redis_pool.with do |conn|
            conn.multi do
              atomic_push(conn, payloads)
            end
          end
          true
        rescue Redis::BaseError, Timeout::Error => e
          args = payloads.first
          worker_class = args['class']
          NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Sidekiq job moved to Shoryuken 
            as error on Redis enqueue, #{e.message}, Worker class is #{worker_class}, Job payload is 
            #{args.inspect}"}})
          return if SIDEKIQ_BATCH_JOBS.include?(worker_class) || args['at']
          Ryuken::SidekiqFallbackWorker.perform_async(args)
          Rails.logger.info 'Sidekiq job moved to Shoryuken'
        end
      end

      def atomic_push(conn, payloads)
        if payloads.first['at']
          conn.zadd('schedule'.freeze, payloads.map do |hash|
            at = hash['at'.freeze].to_s
            [at, Sidekiq.dump_json(hash)]
          end)
        else
          q = payloads.first['queue']
          now = Time.now.to_f
          to_push = payloads.map do |entry|
            entry['enqueued_at'.freeze] = now
            Sidekiq.dump_json(entry)
          end
          conn.sadd('queues'.freeze, q)
          conn.lpush("queue:#{q}", to_push)
        end
      end
  end
end