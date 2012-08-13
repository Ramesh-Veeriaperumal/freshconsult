class Integrations::InstalledApplicationsController < Admin::AdminController
  
  include Integrations::AppsUtil

  before_filter :load_object 
  before_filter :check_jira_authenticity, :only => [:install, :update]
  before_filter :strip_slash, :only => [:install, :update]
  
  def install # also updates
    Rails.logger.debug "Installing application with id "+params[:id]
    if @installed_application.blank?
      @installed_application = Integrations::InstalledApplication.new(params[:integrations_installed_application])
      @installed_application.application = @installing_application
      @installed_application.account = current_account
      @installed_application[:configs] = convert_to_configs_hash(params)

      begin
        successful = @installed_application.save!
        if successful
          if @installing_application.name == "google_contacts"
            Rails.logger.info "Redirecting to google_contacts oauth."
            redirect_to "/auth/google?origin=install"
            return
          end
          flash[:notice] = t(:'flash.application.install.success')   
        else
          flash[:error] = t(:'flash.application.install.error')
        end
      rescue => e
        Rails.logger.error "Problem in installing an application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        flash[:error] = t(:'flash.application.install.error')
      end
    else
      flash[:error] = t(:'flash.application.already')
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def update
    if @installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
    else
      @installed_application.configs = convert_to_configs_hash(params)
      begin
        @installed_application.save!
        flash[:notice] = t(:'flash.application.configure.success')   
      rescue => e
        Rails.logger.error "Problem in updating an application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        flash[:error] = t(:'flash.application.configure.error')
      end
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end
  
  def edit
    if @installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
      redirect_to :controller=> 'applications', :action => 'index'
    elsif @installed_application.application.system_app?
      @installing_application = @installed_application.application
      @installed_application.configs_password = '' unless @installed_application.configs_password.blank?
    else
      render "integrations/applications/edit"
    end
  end
  
  def uninstall
    begin
      success = @installed_application.destroy
      if success
        flash[:notice] = t(:'flash.application.uninstall.success')
      else
        flash[:error] = t(:'flash.application.uninstall.error')
      end
    rescue => e
      Rails.logger.error "Problem in uninstalling an application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      flash[:error] = t(:'flash.application.uninstall.error')
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end
  
  private
    def convert_to_configs_hash(params)
      if params[:configs].blank?# TODO: need to encrypt the password and should not print the password in log file.
        {:inputs => {}}  
      else
        params[:configs] = get_encrypted_value(params[:configs]) unless params[:configs].blank?
        if(params[:configs][:password] == '')
          params[:configs][:password] = @installed_application.configs[:inputs][:password.to_s] unless @installed_application.configs[:inputs][:password.to_s].blank?
        end
        params[:configs][:domain] = params[:configs][:domain] + params[:configs][:ghostvalue] unless params[:configs][:ghostvalue].blank? or params[:configs][:domain].blank?
        {:inputs => params[:configs].to_hash || {}}  
      end
    end

    def decrypt_password  
      pwd_encrypted = @installed_application.configs_password unless @installed_application.configs.blank?
      pwd_decrypted = Integrations::AppsUtil.get_decrypted_value(pwd_encrypted) unless pwd_encrypted.blank?
      return pwd_decrypted
    end

    def load_object
      if params[:action] == "install"
        @installing_application = Integrations::Application.available_apps(current_account.id).find(params[:id])
        @installed_application = current_account.installed_applications.find_by_application_id(@installing_application)
      else
        @installed_application = current_account.installed_applications.find(params[:id])
        @installing_application = @installed_application.application
      end
    end

    def check_jira_authenticity
      if @installing_application.name == "jira"
        begin
          username = params[:configs][:username]
          password = decrypt_password if params[:configs][:password].blank? and !@installed_application.configs.blank?
          jiraObj = Integrations::JiraIssue.new(username, password, nil, params[:configs][:domain])
          jira_version = jiraObj.jira_serverinfo
        rescue Exception => msg
          if msg.to_s.include?("Exception:")
            msg = msg.to_s.split("Exception:")[1]
          elsif msg.to_s.include?("execution expired")
            msg = "Could not establish connection with your Jira Instance. Please verify the URL and try again" 
          end
          flash[:error] = " Jira reports the following error : #{msg}" unless msg.blank?
          redirect_to :controller=> 'applications', :action => 'index'
        end
      end
    end

    def strip_slash
      params[:configs][:domain] = params[:configs][:domain][0..-2] if !(params[:configs].blank?) and !(params[:configs][:domain].blank?) and params[:configs][:domain].ends_with?('/')
    end

end
