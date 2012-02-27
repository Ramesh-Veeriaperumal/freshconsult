class Integrations::InstalledApplicationsController < Admin::AdminController
  
  include Integrations::AppsUtil
  include Integrations::JiraSystem
  
  def install # also updates
    Rails.logger.debug "Installing application with id "+params[:id]
    installing_application = Integrations::Application.find(params[:id])
    installed_application = current_account.installed_applications.find_by_application_id(installing_application)
    if installed_application.blank?
      installed_application = Integrations::InstalledApplication.new
      installed_application.application = installing_application
      installed_application.account = current_account
      params[:configs][:domain] = params[:configs][:domain][0..-2] if installing_application.name == "jira" and params[:configs][:domain].ends_with?('/')
      installed_application.configs = convert_to_configs_hash(params)

      begin
        successful = installed_application.save!
        if successful
          if installing_application.name == "google_contacts"
            Rails.logger.info "Redirecting to google_contacts oauth."
            redirect_to "/auth/google?origin=install"
            return
          end
          if installing_application.name == "jira"
           check_jira_authenticity(params, installed_application)
          end
          unless $update_error
            flash[:notice] = t(:'flash.application.install.success')   
          end
        else
          flash[:error] = t(:'flash.application.install.error')
        end
      rescue Exception => msg
        puts "Something went wrong while configuring an installed ( #{msg})"
        flash[:error] = t(:'flash.application.install.error')
      end
    else
      flash[:error] = t(:'flash.application.already')
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end
  
  def update
    installed_application = current_account.installed_applications.find(params[:id])
    installing_application = installed_application.application
    if installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
    else
      params[:configs][:domain] = params[:configs][:domain][0..-2] if installing_application.name == "jira" and params[:configs][:domain].ends_with?('/')
      installed_application.configs = convert_to_configs_hash(params)
      begin
        installed_application.save!
        if installing_application.name == "jira"
          check_jira_authenticity(params, installed_application)
        end
        unless $update_error
          flash[:notice] = t(:'flash.application.configure.success')   
        end
      rescue Exception => msg
        puts "Something went wrong while configuring an installed ( #{msg})"
        flash[:error] = t(:'flash.application.configure.error')
      end
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end
  
  def configure
    @installed_application = current_account.installed_applications.find(params[:id])
    if @installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
      redirect_to :controller=> 'applications', :action => 'index'
    else
      @installing_application = @installed_application.application
      return @installing_application
    end
  end
  
  def uninstall
    begin
      installedApp = current_account.installed_applications.find(params[:id])
      success = installedApp.destroy
      if success
        flash[:notice] = t(:'flash.application.uninstall.success')
      else
        flash[:error] = t(:'flash.application.uninstall.error')
      end
    rescue Exception => e
      puts "Something went wrong while uninstalling an installed app ( #{e})"
      flash[:error] = t(:'flash.application.uninstall.error')
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end
  
  private
  def convert_to_configs_hash(params)
    unless params[:configs].blank?# TODO: need to encrypt the password and should not print the password in log file.
      params[:configs][:password] = get_encrypted_value(params[:configs][:password]) unless params[:configs][:password].blank?
      params[:configs][:domain] = params[:configs][:domain] + params[:configs][:ghostvalue] unless params[:configs][:ghostvalue].blank? or params[:configs][:domain].blank?
       
      {:inputs => params[:configs].to_hash}  
    end
  end

  def decrypt_password  
    pwd_encrypted = @installed_application.configs[:inputs]['password']
    pwd_decrypted = Integrations::AppsUtil.get_decrypted_value(pwd_encrypted) unless pwd_encrypted.blank?
    return pwd_decrypted
  end

  def check_jira_authenticity(params, installed_application)
    $update_error = false
    begin
      jira_version = jira_authenticity(params)
      if jira_version.blank?
        flash[:error] = "Could not establish connection with the Jira Instance. Please verify your URL and try again" 
        $update_error = true
      end        
    rescue Exception => msg
      if msg.to_s.include?("Exception:")
        msg = msg.to_s.split("Exception:")[1]
      end
      flash[:error] = " Jira reports the following error : #{msg}" unless msg.blank?
      installed_application.destroy
      $update_error = true
    end
  end

end
