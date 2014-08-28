class ExceptionsController < ActionController::Base
  def show
    render :file => "#{Rails.root}/public/404"
  end
end