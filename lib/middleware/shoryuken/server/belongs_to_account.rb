module Middleware
  module Shoryuken
    module Server
      class BelongsToAccount
             
        IGNORE = []

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end
  
        def call(worker_instance, queue, sqs_msg, body)
          if !@ignore.include?(worker_instance.class.name)
            ::Account.reset_current_account
            account_id = body['account_id']
            Sharding.select_shard_of(account_id) do
              account = ::Account.find(account_id)
              account.make_current
            end
          end
          time_spent = Benchmark.realtime { yield }
        rescue DomainNotReady => e
          puts "Just ignoring the DomainNotReady , #{e.inspect}"
        rescue Exception => e
          puts e.backtrace
            # NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end
