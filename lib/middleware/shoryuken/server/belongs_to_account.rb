module Middleware
  module Shoryuken
    module Server
      class BelongsToAccount
  
        def call(worker_instance, queue, sqs_msg, body)
          begin
            ::Account.reset_current_account
            account_id = body['account_id']
            Sharding.select_shard_of(account_id) do
              account = ::Account.find(account_id)
              account.make_current
              time_spent = Benchmark.realtime { yield }
            end
          rescue DomainNotReady => e
            puts "Just ignoring the DomainNotReady , #{e.inspect}"
          rescue Exception => e
            # NewRelic::Agent.notice_error(e)
          end
        end
      end
    end
  end
end