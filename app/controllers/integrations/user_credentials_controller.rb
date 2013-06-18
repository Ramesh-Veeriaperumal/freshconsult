class Integrations::UserCredentialsController < ApplicationController
  include Integrations::AppsUtil
  
  def oauth_install
    begin
      app_config = KeyValuePair.find_by_account_id_and_key(current_account.id, "#{params['id']}_oauth_config")
      unless app_config.blank?
        config_hash = JSON.parse(app_config.value)
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
        app_config.delete
      end	
    rescue Exception => msg
      puts "Something went wrong while configuring an installed application ( #{msg})"
      flash[:error] = t(:'flash.application.install.error')
    end

      redirect_back_using_cookie(request, privilege?(:admin_tasks) ? integrations_applications_path : root_path )
  end
  
end
