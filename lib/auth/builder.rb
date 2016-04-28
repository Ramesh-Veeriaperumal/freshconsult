module Auth
  class Builder < OmniAuth::Builder

    def initialize(app, &block)
      @app = app
      super(app, &block)
    end

    # Omniauth::Builder registers many nested middlewares for each strategy provider we the pass to the initialize block arg.
    # Allow only "/auth" requests to go to Omniauth::Builder middleware stack for better performance and skip other requests.
    # Tradeoff: Any strategy registered with a custom "path_prefix" option other then the default path_prefix "/auth" will not work. 
    def call(env)
      if env['PATH_INFO'].split("/")[1] == "auth"
        super(env)
      else
        @status, @headers, @response = @app.call(env)
      end
    end
  end
end