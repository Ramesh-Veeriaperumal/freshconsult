class Integrations::InstalledApplicationsController < ApplicationController

  include Integrations::AppsUtil

  def index
    @applications = Integrations::Application.all
    @installed_applications = get_installed_apps
    render :template=> 'integrations/applications/index'
  end

  def install # also updates
    Rails.logger.debug "Installing application with id "+params[:id]
    installing_application = Integrations::Application.find(params[:id])
    installed_application = Integrations::InstalledApplication.find(:all, :conditions => ["application_id = ? and account_id = ?", installing_application, current_account])
    if installed_application.blank?
      installed_application = Integrations::InstalledApplication.new
      installed_application.application = installing_application
      installed_application.account = current_account
      installed_application.configs = convert_to_configs_hash(params)
      installed_application.save
    else
      flash[:error] = t(:'flash.application.already')
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def update
    installed_application = Integrations::InstalledApplication.find(params[:id])
    installed_application.configs = convert_to_configs_hash(params)
    installed_application.save
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def configure
    @installed_application = Integrations::InstalledApplication.find(params[:id])
    @installing_application = Integrations::Application.find(@installed_application.application)
  end

  def uninstall
    Integrations::InstalledApplication.delete(params[:id])
    redirect_to :controller=> 'applications', :action => 'index'
  end
  
  private
    def convert_to_configs_hash(params)
      return {:inputs => params[:configs].to_hash} # TODO: need to encrypt the password and should not print the password in log file.
    end
end
