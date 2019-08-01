module Tasks
  module Helpers
    module Errors
      class UnknownTaskTrigger < StandardError
      end

      class UnknownRunMode < StandardError
      end

      class TaskBlockMissing < StandardError
      end

      class RetryExhausted < StandardError
      end

      class NotOKWebhookResponse < StandardError
      end
    end
  end
end
