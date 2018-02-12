class HealthCheckupController < ActionController::Metal

  INFRA = YAML.load_file(File.join(Rails.root, 'config', 'infra_layer.yml'))

  include ActionController::Head

  def app_health_check
    if check_asset_compilation && !File.exists?("/tmp/helpkit_app_restart.txt")
      head @status
    else
      head :internal_server_error
    end
  end

  def check_asset_compilation
    @status = (ASSETS_DIRECTORY_EXISTS || INFRA['PRIVATE_API'] || INFRA['API_LAYER']) ? :ok : nil # Escape asset existence check for falcon apps
  end

end
