module Middleware
  module Sidekiq
    module Server
      class BelongsToAccount

        IGNORE = []

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end

        def call(worker, msg, queue)
          #Logic starts to add uuid and job id to log tags to debug
          # begin
          #   log_tags = (msg.try(:[], 'message_uuid') || [])
          #   log_tags << msg["jid"]
          #   Thread.current[:message_uuid] = log_tags
          # rescue Exception => e
          #   log_tags = []
          # end
          #Logic ends to add uuid and job id to log tags to debug

          #Rails.logger.tagged(log_tags) do
            if !@ignore.include?(worker.class.name)
              ::Account.reset_current_account
              account_id = msg['account_id']
              Sharding.select_shard_of(account_id) do
                account = ::Account.find(account_id)
                account.make_current
                time_spent = Benchmark.realtime { yield }
              end
            else
              yield
            end
          #end
        rescue DomainNotReady => e
            puts "Just ignoring the DomainNotReady , #{e.inspect}"
        rescue ShardNotFound => e
            puts "Ignoring ShardNotFound, #{e.inspect}, #{msg['account_id']}"
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        ensure
          Thread.current[:message_uuid] = nil
        end
      end
    end
  end
end