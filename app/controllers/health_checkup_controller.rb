class HealthCheckupController < ActionController::Metal

  include ActionController::Head

  def app_health_check
    if check_asset_compilation
      head @status
    else
      head :internal_server_error
    end
  end

  def check_asset_compilation 
    @status = ASSETS_DIRECTORY_EXISTS ? :ok : nil
  end

end