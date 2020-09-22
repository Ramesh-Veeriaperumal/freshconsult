require 'securerandom'
class Integrations::InstalledApplicationsController < Admin::AdminController

  class VersionDetectionError < Exception; end
  include Integrations::AppsUtil
  include Integrations::Slack::SlackConfigurationsUtil #Belongs to Old Slack. Remove when Slack v1 is obselete.
  include Redis::OthersRedis

  before_filter { |c| c.requires_feature :marketplace }
  before_filter :strip_slash, :only => [:install, :update]
  before_filter :load_object
  before_filter :check_application_installable, :only => [:install, :update]
  before_filter :set_auth_key, :only => [:install,:update]
  # before_filter :check_jira_authenticity, :only => [:install, :update]
  before_filter :populate_zoho_domain, :only => [:install, :update], :if => :application_is_zoho?
  before_filter :redirect_old_slack, :only => [:update], :if => :application_is_slack? #Remove this when slackv1 is obselete.
  before_filter :update_ratelimit, :only => [:update] #For security, prevent port scanning.
  after_filter  :destroy_all_slack_rule, :only => [:uninstall], :if =>  :application_is_slack? #Remove this when slackv1 is obselete.



  def install 
  # also updates
    Rails.logger.debug "Installing application with id "+params[:id]
    if @installing_application.cti?
      if current_account.cti_installed_app_from_cache
        flash[:notice] = t(:'flash.application.install.cti_error')
        redirect_to integrations_applications_path and return
      end
      if current_account.freshfone_active?
        flash[:notice] = t(:'flash.application.install.freshfone_alert')
        redirect_to :controller=> 'applications', :action => 'index'
        return
      end
    end
    begin
      successful = @installed_application.save!
      if successful
        if @installing_application.name == "google_contacts"
          Rails.logger.info "Redirecting to google_contacts oauth."
          oauth_url = @installed_application.application.oauth_url({:account_id => current_account.id, :portal_id => current_portal.id})
          redirect_to "#{oauth_url}" and return
        end
        flash[:notice] = t(:'flash.application.install.success')
      else
        flash[:error] = t(:'flash.application.install.error')
      end
    rescue VersionDetectionError => e
      flash[:error] = t("integrations.batchbook.detect_error")
    rescue PlanUpgradeError => e
      flash[:error] = t(:'integrations.adv_features.unavailable')
    rescue => e
      Rails.logger.error "Problem in installing an application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      flash[:error] = t(:'flash.application.install.error')
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def update
    if @installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
    else
      begin
        @installed_application.save!
        flash[:notice] = t(:'flash.application.update.success')
      rescue VersionDetectionError => e
        flash[:error] = t("integrations.batchbook.detect_error")
      rescue => e
        Rails.logger.error "Problem in updating an application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        flash[:error] = t(:'flash.application.update.error')
      end
    end
    respond_to do |format|
      format.json do
        render :json => {:status => "Success"}
      end
      format.html do
        redirect_to :controller=> 'applications', :action => 'index'
      end
    end
  end

  def edit
    if @installed_application.blank?
      flash[:error] = t(:'flash.application.not_installed')
      redirect_to :controller=> 'applications', :action => 'index'
    elsif @installed_application.application.system_app?
      @installing_application = @installed_application.application
      @installed_application.configs_password = '' unless @installed_application.configs_password.blank?

      if @installing_application.name == Integrations::Constants::APP_NAMES[:shopify]
        primary_store = { shop_name: @installed_application.configs[:inputs]['shop_name'], shop_display_name: @installed_application.configs[:inputs]['shop_display_name'] || @installed_application.configs[:inputs]['shop_name'] }
        additional_stores = []
        if @installed_application.configs[:inputs]['additional_stores'].present?
          @installed_application.configs[:inputs]['additional_stores'].keys.each do |key|
            additional_stores << { shop_name: key, shop_display_name: @installed_application.configs[:inputs]['additional_stores'][key]['shop_display_name'] || key }
          end
        end
        @stores = [primary_store, additional_stores].flatten
        render 'integrations/installed_applications/shopify/falcon_edit'
      end
    else
      render "integrations/applications/edit"
    end
  end

  def uninstall
    begin
      obj = @installed_application.destroy
      if obj.destroyed?
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
  
  #Since enabling SEOshop from Freshdesk is disabled, this check is made
  def check_application_installable
    app = params[:action] == "install" ? @installing_application.name : @installed_application.application.name
    if app == "seoshop"
      redirect_to :controller=> 'applications', :action => 'index'
    end
  end

  def convert_to_configs_hash(params) #possible dead code
    if params[:configs].blank?
      {:inputs => {}}
    else
      params[:configs][:domain] = params[:configs][:domain] + params[:configs][:ghostvalue] unless params[:configs][:ghostvalue].blank? or params[:configs][:domain].blank?
      {:inputs => params[:configs].to_hash || {}}
    end
  end

  def load_object
    if params[:action] == "install"
      @installing_application = Integrations::Application.available_apps(current_account.id).find(params[:id])
      @installed_application = current_account.installed_applications.find_by_application_id(@installing_application)
      if @installed_application.blank?
        @installed_application = Integrations::InstalledApplication.new(params[:integrations_installed_application])
        @installed_application.application = @installing_application
        @installed_application.account = current_account
      else
        flash[:error] = t(:'flash.application.already')
        redirect_to :controller=> 'applications', :action => 'index'
      end
    else
      @installed_application = current_account.installed_applications.find(params[:id])
      @installing_application = @installed_application.application
      @channels = channel_name if @installing_application.slack? 
    end
    @installed_application.set_configs params[:configs]
    @installed_application.set_configs({"OAuth2" => []}) if @installing_application.name == "google_contacts"
  end

  def set_auth_key
    if @installing_application.name == "jira"
      auth_key_salt = SecureRandom.hex(10)
      @installed_application[:configs][:inputs][:auth_key] = Digest::MD5.hexdigest(params[:configs][:domain] + current_account.id.to_s + auth_key_salt + Time.new.to_f.to_s)
    end
  end
  
  def check_jira_authenticity
    if @installing_application.name == "jira"
      begin
        response = Integrations::JiraIssue.new(@installed_application).authenticate
        if(response[:exception])
          flash[:error] = "jira reports the following error : #{response[:error].split(':')[1]}"
          redirect_to :controller=> 'applications', :action => 'index'
        end
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
    params[:configs][:domain] = params[:configs][:domain][0..-2] if !params[:configs].blank? and !params[:configs][:domain].blank? and params[:configs][:domain].ends_with?('/')
  end

  def redirect_old_slack #Remove when slackv1 is obselete
    flash[:error] = t('integrations.slack_msg.uninstall_old_slack')
    redirect_to integrations_applications_path and return
  end

  def application_is_slack? #Remove when slackv1 is obselete
    @installing_application.present? && @installing_application.slack?
  end

  def application_is_zoho?
    @installing_application.present? && @installing_application.zohocrm?
  end

  def populate_zoho_domain
    @installed_application.configs_domain = get_zohocrm_pod @installed_application.configs_api_key
  end

  def update_ratelimit
    app_name = @installing_application.name
    if ['jira', 'czentrix'].include?(app_name)
      whitelist_key = "UPDATEWHITELIST_#{current_account.id}_#{app_name}"
      count = increment_others_redis(whitelist_key)
      Rails.logger.debug "setting ratelimit count for account #{current_account.id} and app #{app_name} : #{count}"
      set_others_redis_expiry(whitelist_key, 3600) if(count == 1)
      render :text => RateLimitHtml::HTML, :status => :forbidden if(count > 5) #Ratelimit updates to 5 per hour.
    end
  end
end
