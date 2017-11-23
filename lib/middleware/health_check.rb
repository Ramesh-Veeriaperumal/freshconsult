module Middleware
  class HealthCheck
  
    INFRA = YAML.load_file(File.join(Rails.root, 'config', 'infra_layer.yml'))

    def initialize(app)
      @app = app
    end

    def call(env)
      if HEALTH_CHECK_PATH["allowed_routes"].include?(env['PATH_INFO'])
        if check_asset_compilation && !File.exists?("/tmp/helpkit_app_restart.txt")
          [200, {'Content-Type' => 'text/plain'}, ["Success"]]
        else
          [500, {'Content-Type' => 'text/plain'}, ["Failure"]]
        end
      else
        @status, @headers, @response = @app.call(env)
      end
    end

    def check_asset_compilation 
      @check = ASSETS_DIRECTORY_EXISTS ? :ok : (INFRA['PRIVATE_API'] ? :ok : nil) # Escape asset existence check for falcon apps
    end
  end
end