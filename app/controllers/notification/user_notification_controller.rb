class Notification::UserNotificationController < ApplicationController
  
  JWT_ALGO = 'HS256'

  def index
    @cache_content = notifications_content
    render :layout => false
  end

  def token
    token = JWT.encode payload, iris_jwt_secret, JWT_ALGO
    render :json => { :jwt => token }
  end

  private
  def notifications_content
    render_to_string :partial => 'notification/user_notification'
  end 

  def payload
    { :account_id => current_account.id.to_s, :user_id => current_user.id.to_s, :service_name => IrisNotificationsConfig["service_name"], :jti => Digest::MD5.hexdigest(Time.now.to_i.to_s)}
  end

  def iris_jwt_secret
    IrisNotificationsConfig["shared_secret"]
  end
end
