class Support::Integrations::UserCredentialsController < ApplicationController
  include Integrations::OauthHelper
  include Integrations::AppsUtil

  skip_before_filter :check_privilege
  before_filter { |c| c.check_customer_app_access c.params[:app_name] }

  def oauth_install
    begin
      key_options = { :account_id => current_account.id, :provider => params[:app_name]}
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      kv_store = Redis::KeyValueStore.new(key_spec)
      kv_store.group = :integration
      app_config = kv_store.get_key
      unless app_config.blank?
        config_hash = JSON.parse(app_config)
        app_name = config_hash["app_name"]
        config_hash.delete("app_name")      
        installed_application = current_account.installed_applications.find_by_application_id(
                                                Integrations::Application.find_by_name(app_name).id)
        Integrations::UserCredential.add_or_update(installed_application, current_user.id, config_hash)     
        kv_store.remove_key
      end 
    rescue Exception => msg
      puts "Something went wrong while configuring an installed application ( #{msg})"
      flash[:error] = t(:'flash.application.install.error')
    end
    redirect_back_using_cookie(request, root_path )
  end

  def refresh_access_token
    begin
      app_name = params[:app_name]
      app = Integrations::Application.find_by_name(app_name)
      inst_app = current_account.installed_applications.find_by_application_id(app.id)
      user_credential = inst_app.user_credentials.find_by_user_id(current_user.id)
      refresh_token = user_credential.auth_info['refresh_token']
      access_token = get_oauth2_access_token(app.oauth_provider, refresh_token, app_name)
      user_credential.auth_info.merge!( { 'oauth_token' => access_token.token } )
      user_credential.auth_info.merge!({'refresh_token' => access_token.refresh_token}) if app_name == "box"
      user_credential.save!           
      render :json => { :access_token => access_token.token }
    rescue Exception => e
       Rails.logger.error "Error getting access token from #{app_name}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      render :json => { :error=> "Error getting access token for #{params[:app_name]}" }
    end
  end

end