class RabbitMqController < ApplicationController

  skip_before_filter :check_privilege, :verify_authenticity_token

  def index
    if params[:secret_key] && params[:secret_key] == $rabbitmq_config["secret_key"]
      exchanges = $rabbitmq_model_exchange.map { |key, exchange| exchange.name}
      render :json => { :available_exchanges => exchanges }
    else
      render :json => { :error => "page not found" }, :status => 404
    end
  end
end