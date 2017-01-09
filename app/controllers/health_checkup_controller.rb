class HealthCheckupController < ActionController::Metal

  include ActionController::Head

  def app_health_check
    head :ok
  end

end