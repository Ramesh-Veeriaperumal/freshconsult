module Middleware
  module Sidekiq
    module Client
      class SetCurrentUser
  
        INCLUDE = []

        def initialize(options = {})
          @included = options.fetch(:required_classes, INCLUDE)
        end

        def call(worker, msg, queue,redis_pool)
          if @included.include?(worker.to_s)
            msg['current_user_id'] = ::User.current.id if ::User.current
          end
          yield
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end
