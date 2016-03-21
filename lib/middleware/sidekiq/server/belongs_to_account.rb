module Middleware
  module Sidekiq
    module Server
      class BelongsToAccount

        IGNORE = []

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end

        def call(worker, msg, queue)
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
        rescue DomainNotReady => e
            puts "Just ignoring the DomainNotReady , #{e.inspect}"
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end