module Middleware
  module Sidekiq
    module Server
      class SetCurrentUser

        INCLUDE = []

        def initialize(options = {})
          @included = options.fetch(:required_classes, INCLUDE)
        end

        def call(worker, msg, queue)
          if @included.include?(worker.class.name)
            ::User.reset_current_user
            current_account = ::Account.current
            fail Middleware::Sidekiq::SidekiqErrors::InvalidCurrentAccountException,"Invalid current account" if current_account.nil?
            fail Middleware::Sidekiq::SidekiqErrors::InvalidCurrentUserException, "Invalid current user" if msg['current_user_id'].nil?
            user_id = msg['current_user_id']
            user = current_account.users.find_by_id(user_id)
            fail Middleware::Sidekiq::SidekiqErrors::InvalidCurrentUserException, "Invalid current user" if user.nil?
            user.make_current
            time_spent = Benchmark.realtime { yield }
          else
            yield
          end
          # rescue DomainNotReady => e
          #   puts "Just ignoring the DomainNotReady , #{e.inspect}"
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end