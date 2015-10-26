module Integrations::Marketplace::LoginHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Integrations::Marketplace::RedirectUrlHelper
  
  def find_account_by_remote_id(remote_id, app_name)
    if remote_id.present?
      account_id = nil
      remote_integ_map = "Integrations::#{app_name.camelize}RemoteUser".constantize.find_by_remote_id(remote_id)
      if remote_integ_map.present?
        account_id = remote_integ_map.account_id
      end
      account_id
    end
  end

  def get_remote_integ_mapping(remote_id, app_name)
    "Integrations::#{app_name.camelize}RemoteUser".constantize.find_by_remote_id(remote_id)
  end

  def set_redis_and_redirect(app_name, account, remote_id, email, operation)
    set_redis_key_for_sso(app_name, remote_id, email)
    redirect_url = account.full_url + integrations_marketplace_login_login_path + "?app_name=" + app_name + "&remote_id=" + remote_id.to_s + "&operation=" + operation
    redirect_to redirect_url
  end

  def set_redis_key_for_sso(app_name, remote_id, email)
    redis_oauth_key = app_name + '_SSO:' + remote_id
    set_others_redis_key(redis_oauth_key, email, 300)
  end

  def get_user(account, email)
    account.user_emails.user_for_email(email)
  end

  def update_remote_integrations_mapping(app_name, remote_id, account, user)
    "Integrations::#{app_name.camelize}RemoteUser".constantize.create!(:account_id => account.id,
      :remote_id => remote_id, :configs => { :user_id => user.id, :user_email => user.email })
  end

  def verify_user_and_redirect(user)
    if user.privilege?(:manage_account)
      update_remote_integrations_mapping(@app_name, @remote_id, @account, user)
      set_redis_and_redirect(@app_name, @account, @remote_id, @email, @operation)
    else
      render :template => 'integrations/marketplace/error', :locals => { :error_type => 'insufficient_privilege' }
    end
  end

  def create_user_session(user)
    @user_session = current_account.user_sessions.new(user)
    redirect_url = get_redirect_url
    if @user_session.save
      return unless grant_day_pass
      if user.privilege?(:admin_tasks)
        redirect_to redirect_url
      else
        redirect_back_or_default('/')
      end
    else
      redirect_to login_url
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

  def get_redirect_url
    send(params[:app_name] + '_url')
  end

end
