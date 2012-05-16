class Integrations::InstalledApplicationsController < Admin::AdminController
  
  include Integrations::AppsUtil
  include Integrations::JiraSystem

  before_filter :load_object 
  before_filter :check_jira_authenticity, :only => [:install, :update]
  before_filter :strip_slash, :only => [:install, :update]
  
  def install # also updates
    Rails.logger.debug "Installing application with id "+params[:id]
    if @installed_application.blank?
      @installed_application = Integrations::InstalledApplication.new
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
          elsif @installing_application.name == "salesforce"
            Rails.logger.info "Redirecting to salesforce oauth."
            redirect_to "/auth/salesforce?origin=#{current_account.id}"
            Rails.logger.info "URL redirect fail"
            return
          end
          flash[:notice] = t(:'flash.application.install.success')   
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
    if @installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
    else
      @installed_application.configs = convert_to_configs_hash(params)
      begin
        @installed_application.save!
        flash[:notice] = t(:'flash.application.configure.success')   
      rescue Exception => msg
        puts "Something went wrong while configuring an installed ( #{msg})"
        flash[:error] = t(:'flash.application.configure.error')
      end
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end
  
  def configure
    if @installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
      redirect_to :controller=> 'applications', :action => 'index'
    else
      @installing_application = @installed_application.application
      @installed_application.configs[:inputs][:password.to_s] = '' unless @installed_application.configs[:inputs][:password.to_s].blank?
      return @installing_application
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
    rescue Exception => e
      puts "Something went wrong while uninstalling an installed app ( #{e})"
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
        @installing_application = Integrations::Application.find(params[:id])
        @installed_application = current_account.installed_applications.find_by_application_id(@installing_application)
      else
        @installed_application = current_account.installed_applications.find(params[:id])
        @installing_application = @installed_application.application
      end
    end

    def check_jira_authenticity
      if @installing_application.name == "jira"
        begin
          params[:configs][:password] = decrypt_password if params[:configs][:password].blank? and !@installed_application.configs.blank?
          jira_version = jira_authenticity(params)   
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
