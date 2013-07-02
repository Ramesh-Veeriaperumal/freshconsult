class Integrations::UserCredentialsController < ApplicationController
  include Integrations::AppsUtil
  
  def oauth_install
    begin
      key_options = { :account_id => current_account.id, :provider => params['id']}
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      kv_store = Redis::KeyValueStore.new(key_spec)
      kv_store.group = :integration
      app_config = kv_store.get_key
      unless app_config.blank?
        config_hash = JSON.parse(app_config)
        app_name = config_hash["app_name"]
        config_hash.delete("app_name")	    
        
        if privilege?(:admin_tasks)
          Integrations::Application.install_or_update( app_name, current_account.id ) 
        end
      
        installed_application = current_account.installed_applications.find_by_application_id(
                                                Integrations::Application.find_by_name(app_name).id)
                  
        Integrations::UserCredential.add_or_update(installed_application, current_user.id, config_hash)	    
        flash[:notice] = t(:'flash.application.install.success') if installed_application and 
                          request.cookies.fetch('return_uri', '').blank?
  	    kv_store.remove_key
      end	
    rescue Exception => msg
      puts "Something went wrong while configuring an installed application ( #{msg})"
      flash[:error] = t(:'flash.application.install.error')
    end

      redirect_back_using_cookie(request, privilege?(:admin_tasks) ? integrations_applications_path : root_path )
  end
  
end
