module Middleware
  module Shoryuken
    module Server
      class SidekiqFallback

        REQUIRE = []

        def initialize(options = {})
          @required = options.fetch(:require, REQUIRE)
        end
        
        def call(worker_instance, queue, sqs_msg, body)
          if @required.include?(worker_instance.class.to_s)
            if !body['account_id'].nil?
              begin
                ::Account.reset_current_account
                account_id = body['account_id']
                Sharding.select_shard_of(account_id) do
                  account = ::Account.find(account_id)
                  account.make_current
                  if !body['current_user_id'].nil?
                    ::User.reset_current_user
                    current_account = ::Account.current
                    fail Middleware::Shoryuken::ShoryukenErrors::InvalidCurrentAccountException,"Invalid current account" if current_account.nil?
                    user_id = body['current_user_id']
                    user = current_account.users.find_by_id(user_id)
                    fail Middleware::Shoryuken::ShoryukenErrors::InvalidCurrentUserException, "Invalid current user" if user.nil?
                    user.make_current
                  end
                  time_spent = Benchmark.realtime { yield }
                end
              rescue DomainNotReady => e
                puts "Just ignoring the DomainNotReady , #{e.inspect}"
              rescue Exception => e
                NewRelic::Agent.notice_error(e)
              end
            end
          else
            yield
          end
        end

      end
    end
  end
end