class SsoController < ApplicationController

  skip_before_filter :check_privilege
  
  def login
    auth = Authorization.find_by_provider_and_uid_and_account_id(params['provider'], params['uid'], current_account.id)
    unless auth.blank?
      curr_user = auth.user 
      kv = KeyValuePair.find_by_account_id_and_key(current_account.id, curr_user.id)
      unless kv.blank?
        random_hash = Digest::MD5.hexdigest(kv.value)
        expiry = kv.value.to_i + TIMEOUT 
        curr_time = (DateTime.now.to_f * 1000).to_i
        if(random_hash == params['s'] and curr_time <= expiry)
          user_session = curr_user.account.user_sessions.new(curr_user) 
          kv.delete
          facebook_redirect = '/facebook/support/home' if params[:portal_type] == 'facebook'
          redirect_back_or_default(facebook_redirect || '/') if user_session.save
          return
        end 
      end
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def facebook
    redirect_to "#{AppConfig['integrations_url'][Rails.env]}/auth/facebook?origin=#{current_portal.id}&state=#{params[:portal_type]}"
  end

  TIMEOUT = 60000
end
