module Middleware
  module Sidekiq
    module Server
      class UnsetThread

        def call(worker, msg, queue)
          Middleware::GlobalRequestStore::THREAD_RESET_KEYS.each do |key|
            Thread.current[key] = nil
          end
          yield
        end
      end
    end
  end
end
