module Integrations::Marketplace::LoginHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def find_account_by_remote_id(remote_id, app_name)
    if remote_id.present?
      account_id = nil
      remote_integ_map = "#{remote_integration_class(app_name)}".constantize.find_by_remote_id(remote_id)
      if remote_integ_map.present?
        account_id = remote_integ_map.account_id
      end
      account_id
    end
  end

  def get_remote_integ_mapping(remote_id, app_name)
    if remote_id.present?
      "Integrations::#{app_name.camelize}RemoteUser".constantize.find_by_remote_id(remote_id)
    end
  end

  def set_redis_and_redirect(app_name, account, remote_id, email, operation)
    timestamp = Time.now.utc.to_i.to_s
    set_redis_key_for_sso(app_name, remote_id, email, timestamp)
    redirect_url = account.full_url + integrations_marketplace_login_login_path + "?app_name=" + app_name + "&remote_id=" + remote_id.to_s + "&operation=" + operation + "&timestamp=" + timestamp
    redirect_to redirect_url
  end

  def set_redis_key_for_sso(app_name, remote_id, email, timestamp)
    redis_oauth_key = "#{app_name}_SSO:#{remote_id}:#{timestamp}"
    set_others_redis_key(redis_oauth_key, email, 300)
  end

  def get_user(account, email)
    account.user_emails.user_for_email(email)
  end

  def update_remote_integrations_mapping(app_name, remote_id, account, user)
    "#{remote_integration_class(app_name)}".constantize.create!(:account_id => account.id,
        :remote_id => remote_id, :configs => { :user_id => user.id, :user_email => user.email }) if remote_id.present?
  end

  def verify_user_and_redirect(user)
    if user.privilege?(:manage_account)
      update_remote_integrations_mapping(@app_name, @remote_id, @account, user)
      set_redis_and_redirect(@app_name, @account, @remote_id, @email, @operation)
    elsif proxy_auth_app?(@app_name) && !user.privilege?(:manage_account)
      flash.now[:error] = t(:'flash.g_app.use_admin_cred')
      render "google_signup/proxy_auth"
    else
      render :template => 'integrations/marketplace/error', :locals => { :error_type => 'insufficient_privilege' }
    end
  end

  def make_user_active(user)
    user.active = true
    user.save
  end

  def user_deleted
    flash[:notice] = t('integrations.marketplace_login.error.insufficient_privilege')
    redirect_to login_url
  end

  def get_redirect_url(app_name, account, query_params = {})
    redirect_url = Addressable::URI.parse(Integrations::MARKETPLACE_LANDING_PATH_HASH[app_name])
    query_params = query_params.except(:action, :controller)
    redirect_url.query_values = (redirect_url.query_values || {}).merge(query_params)
    return account.full_url + redirect_url.to_s
  end

  private

    def remote_integration_class app_name
      if app_name == "google"
        "Integrations::#{app_name.camelize}RemoteAccount"
      else
        "Integrations::#{app_name.camelize}RemoteUser"
      end
    end

    def proxy_auth_app? app_name
      proxy_apps = ["google"]
      proxy_apps.include?(app_name)
    end

end
