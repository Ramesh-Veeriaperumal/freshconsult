class Notification::UserNotificationController < ApplicationController
  
  JWT_ALGO = 'HS256'

  def token
    token = JWT.encode payload, iris_jwt_secret, JWT_ALGO
    render :json => { :jwt => token }
  end

  private
  def notifications_content
    render_to_string :partial => 'notification/user_notification'
  end 

  def payload
    payload = { account_id: current_account.id.to_s, user_id: current_user.id.to_s, service_name: IrisNotificationsConfig['service_name'], jti: Digest::MD5.hexdigest(Time.now.to_i.to_s) }
    payload.merge!(freshid_details) if current_account.freshid_org_v2_enabled?
    Rails.logger.info "Notification::UserNotificationController -- payload :: #{payload.inspect}"
    payload
  end

  def freshid_details
    { org_id: current_account.organisation_from_cache.try(:organisation_id), fresh_id: current_user.freshid_authorization.uid }
  end

  def iris_jwt_secret
    IrisNotificationsConfig["shared_secret"]
  end
end
