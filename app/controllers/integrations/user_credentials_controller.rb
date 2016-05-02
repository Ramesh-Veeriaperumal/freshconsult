class Integrations::UserCredentialsController < ApplicationController
  include Integrations::AppsUtil

  before_filter { |c| c.check_agent_app_access(c.params[:app_name]) }
  before_filter :set_app_config, :only => [:oauth_install]

  def oauth_install
    begin
      if @app_config.present?
        install_app
      else
        set_error_message
      end
    rescue Exception => msg
      puts "Something went wrong while configuring an installed application ( #{msg})"
      set_error_message
    end
    redirect_back_using_cookie(request, privilege?(:admin_tasks) ? integrations_applications_path : root_path )
  end

  def create
    app_name = params["app_name"]
    installed_application = current_account.installed_applications.with_name("#{app_name}").first
    options = { :username => params["username"], :password => params["password"] }
    user_credential = Integrations::UserCredential.add_or_update(installed_application, current_user.id, options)
    render :json => user_credential, :status => :created
  end

  private

    def set_app_config
      kv_store = Redis::KeyValueStore.new(fetch_redis_key)
      kv_store.group = :integration
      @app_config = kv_store.get_key
      kv_store.remove_key if @app_config.present?
    end

    def install_app
      config_hash = JSON.parse(@app_config)
      app_name = config_hash["app_name"]
      config_hash.delete("app_name")
      Integrations::Application.install_or_update( app_name, current_account.id ) if privilege?(:admin_tasks)
      installed_application = current_account.installed_applications.with_name("#{app_name}").first

      if installed_application.present?
        Integrations::UserCredential.add_or_update(installed_application, current_user.id, config_hash)
        flash[:notice] = t(:'flash.application.install.success') if request.cookies.fetch('return_uri', '').blank?
      else
        set_error_message
      end
    end

    def fetch_redis_key
      if params[:user_auth].present?
        key_options = { :account_id => current_account.id, :provider => params['id'], :user_id => current_user.id }
        key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_USER_CRED_REDIRECT_OAUTH, key_options)
      else
        key_options = { :account_id => current_account.id, :provider => params['id']}
        key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      end
    end

    def set_error_message
      flash[:error] = t(:'flash.application.install.error')
    end

end
