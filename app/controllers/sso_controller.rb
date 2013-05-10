class SsoController < ApplicationController
  def login
    auth = Authorization.find_by_provider_and_uid_and_account_id(params['provider'], params['uid'], current_account.id)
    unless auth.blank?
      curr_user = auth.user
      key_options = { :account_id => current_account.id, :user_id => curr_user.id, :provider => params['provider']}
      kv_store = Redis::KeyValueStore.new Redis::KeySpec.new(RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
      value = kv_store.get
      unless value.nil?
        random_hash = Digest::MD5.hexdigest(value)
        expiry = value.to_i + TIMEOUT
        curr_time = (DateTime.now.to_f * 1000).to_i
        if(random_hash == params['s'] and curr_time <= expiry)
          user_session = curr_user.account.user_sessions.new(curr_user) 
          kv_store.remove
          session[:facebook_login] = true if params['provider'] == "facebook"
          redirect_back_or_default('/') if user_session.save
          return
        end 
      end
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def facebook
    session[:facebook_tab] = true if params[:facebook_tab]
    redirect_to "#{AppConfig['integrations_url'][Rails.env]}/auth/facebook?origin=#{current_portal.id}"
  end

  TIMEOUT = 60000
end
