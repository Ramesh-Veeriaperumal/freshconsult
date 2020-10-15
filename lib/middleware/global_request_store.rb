require 'rack/body_proxy'

# Inspired from https://github.com/steveklabnik/request_store.
# We are not using the original RequestStore gem because it uses a railstie where the store object is reset after the actiondispatch call stack itself.
# Ideal request store should be available for the entire request-response even in the Middlewares.

# GlobalRequestStore solves the manual overhead involved in reseting Thread.current hash.
# We can use it to solve the current error prone before filter set and unset method inclusions in the first controller.

module Middleware
  class GlobalRequestStore
    THREAD_RESET_KEYS = [
      :account, :user, :portal, :shard_selection, :shard_name_payload, :notifications,
      :email_config, :business_hour, :current_ip, :create_sandbox_account, :language,
      :replica
    ].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      CustomRequestStore.begin!
      response = @app.call(env)
      response << Rack::BodyProxy.new(response.pop) do
        CustomRequestStore.end!
        CustomRequestStore.clear!
      end
    ensure
      unset_thread_variables
      CustomRequestStore.end!
      CustomRequestStore.clear!
    end

    private

      # We are clearing all thread values storing account related info here, to avoid stale values affecting future requests.
      # GlobalRequestStore resumes after controllers and other middlewares that uses these values
      def unset_thread_variables
        THREAD_RESET_KEYS.each do |key|
          Thread.current[key] = nil
        end
      end
  end
end
