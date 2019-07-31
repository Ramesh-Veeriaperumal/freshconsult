module Middleware
  class HealthCheck

    def initialize(app)
      @app = app
    end

    def call(env)
      if HEALTH_CHECK_PATH["allowed_routes"].include?(env['PATH_INFO'])
        if check_asset_compilation && !File.exist?('/tmp/helpkit_app_restart.txt')
          [200, {'Content-Type' => 'text/plain'}, ["Success"]]
        else
          [500, {'Content-Type' => 'text/plain'}, ["Failure"]]
        end
      else
        @status, @headers, @response = @app.call(env)
      end
    end

    private

      def check_asset_compilation
        @check = ASSETS_DIRECTORY_EXISTS ? true : nil
      end
  end
end