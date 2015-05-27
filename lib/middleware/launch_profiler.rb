module Middleware
  class LaunchProfiler
    def initialize(app)
      @app = app
    end

    def call(env)
      @status, @headers, @response = @app.call(env)
      begin
        if env["QUERY_STRING"]["pp"]
          id = JSON.parse(@headers["X-MiniProfiler-Ids"]).first
          Launchy.open("http://localhost:3000/mini-profiler-resources/results?id=#{id}")
        end
      rescue
      end
      [@status, @headers, @response]
    end
  end
end