class HealthCheckupController < ActionController::Metal

  include ActionController::Head

  def app_health_check
    if !File.exists?("/tmp/helpkit_app_restart.txt")
      head @status
    else
      head :internal_server_error
    end
  end
end
