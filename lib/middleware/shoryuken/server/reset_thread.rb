module Middleware
  module Shoryuken
    module Server
      class ResetThread
        def call(worker_instance, _queue, _sqs_msg, _body)
          Middleware::GlobalRequestStore::THREAD_RESET_KEYS.each do |key|
            Thread.current[key] = nil
          end
          yield
        end
      end
    end
  end
end
