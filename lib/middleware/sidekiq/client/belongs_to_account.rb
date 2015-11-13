module Middleware
  module Sidekiq
    module Client
      class BelongsToAccount
  
        IGNORE = []

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end

        def call(worker, msg, queue,redis_pool)
          if !@ignore.include?(worker.to_s)
            msg['account_id'] = ::Account.current.id
          end
          yield
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end
