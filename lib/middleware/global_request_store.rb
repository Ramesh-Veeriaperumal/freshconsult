require 'rack/body_proxy'

# Inspired from https://github.com/steveklabnik/request_store.
# We are not using the original RequestStore gem because it uses a railstie where the store object is reset after the actiondispatch call stack itself.
# Ideal request store should be available for the entire request-response even in the Middlewares.

# GlobalRequestStore solves the manual overhead involved in reseting Thread.current hash.
# We can use it to solve the current error prone before filter set and unset method inclusions in the first controller.

module Middleware
  class GlobalRequestStore
    def initialize(app)
      @app = app
    end

    def call(env)
      CustomRequestStore.begin!
      response = @app.call(env)
      returned = response << Rack::BodyProxy.new(response.pop) do
        CustomRequestStore.end!
        CustomRequestStore.clear!
      end
    ensure
      unless returned
        CustomRequestStore.end!
        CustomRequestStore.clear!
      end
    end
  end
end
