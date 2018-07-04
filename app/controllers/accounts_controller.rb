class AccountsController < ApplicationController

  include ModelControllerMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::TicketsRedis
  include Redis::DisplayIdRedis
  include MixpanelWrapper 
  include Onboarding::OnboardingRedisMethods

  layout :choose_layout 
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:check_domain, :new_signup_free, :email_signup, :signup_validate_domain,
                                                                             :create, :rebrand, :dashboard, :rabbitmq_exchange_info, :edit_domain]

  skip_before_filter :set_locale, :except => [:cancel, :show, :edit, :manage_languages, :edit_domain]
  skip_before_filter :set_time_zone, :set_current_account,
    :except => [:cancel, :edit, :update, :delete_logo, :delete_favicon, :show, :manage_languages, :update_languages, :edit_domain, :validate_domain, :update_domain]
  skip_before_filter :check_account_state
  skip_before_filter :redirect_to_mobile_url
  skip_before_filter :check_day_pass_usage, 
    :except => [:cancel, :edit, :update, :delete_logo, :delete_favicon, :show, :manage_languages, :update_languages]
  skip_filter :select_shard, 

    :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo, :manage_languages, :update_languages, :edit_domain, :validate_domain, :update_domain]
  skip_before_filter :ensure_proper_protocol, :ensure_proper_sts_header,

    :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo, :manage_languages, :update_languages]
  skip_before_filter :determine_pod, 
    :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo, :manage_languages, :update_languages]
  skip_after_filter :set_last_active_time

  around_filter :select_latest_shard, :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo,:manage_languages,:update_languages, :edit_domain, :validate_domain, :update_domain]

  before_filter :validate_signup_email, :only => [:email_signup, :new_signup_free]
  before_filter :check_for_existing_accounts, :only => [:email_signup]

  before_filter :account_unverified?, :only => [:edit_domain, :validate_domain, :update_domain]
  before_filter :ensure_proper_user, :only => [:edit_domain]
  before_filter :check_activation_mail_job_status, :only => [:edit_domain, :update_domain]
  before_filter :validate_domain_name, :only => [:update_domain]
  after_filter  :kill_account_activation_email_job, :only => [:update_domain]
  before_filter :build_user, :only => [ :new, :create ]
  before_filter :build_metrics, :only => [ :create ]
  before_filter :load_billing, :only => [ :show, :new, :create, :payment_info ]
  before_filter :build_plan, :only => [:new, :create]
  before_filter :check_sandbox?, :only => [:cancel]
  before_filter :admin_selected_tab, :only => [:show, :edit, :cancel, :manage_languages  ]
  before_filter :validate_custom_domain_feature, :only => [:update]
  before_filter :build_signup_param, :build_signup_contact, :only => [:new_signup_free, :email_signup]
  before_filter :check_supported_languages, :only =>[:update], :if => :multi_language_available?
  before_filter :set_native_mobile, :only => [:new_signup_free ]
  before_filter :set_additional_signup_params, :only => [:email_signup]
  before_filter :validate_feature_params, :only => [:update]
  before_filter :update_language_attributes, :only => [:update_languages]
  before_filter :validate_portal_language_inclusion, :only => [:update_languages]
  before_filter(:only => [:manage_languages]) { |c| c.requires_feature :multi_language }
  
  def show
  end   
   
  def edit
    @supported_languages_list = current_account.account_additional_settings.supported_languages
    @ticket_display_id = current_account.get_max_display_id
    @restricted_helpdesk = current_account.restricted_helpdesk?
    @restricted_helpdesk_launched = current_account.helpdesk_restriction_enabled?
    if current_account.features?(:redis_display_id)
      key = TICKET_DISPLAY_ID % { :account_id => current_account.id }
      redis_display_id = get_display_id_redis_key(key).to_i
      @ticket_display_id = redis_display_id if redis_display_id > @ticket_display_id
    end
  end
  
  def check_domain
    puts "#{params[:domain]}"
    render :json => { :account_name => true }, :callback => params[:callback]
  end

  def email_signup
    @signup = Signup.new(params[:signup])
    if @signup.save
      finish_signup
      respond_to do |format|
        format.json {
          render :json => { :success => true,
                            :url => edit_account_domain_url(:perishable_token => @signup.user.perishable_token, :host => @signup.account.full_domain),
                            :callback => params[:callback],
                            :account_id => @signup.account.id
                          }
        }
      end
    else
      respond_to do |format|
        format.json {
          render :json => { :success => false, :errors => @signup.all_errors }, :callback => params[:callback]
        }
      end
    end
  end

  # Enables user to edit domain name & support email.
  # Scheduling a job for 10 min. If the user did not submit the form before the scheduled time,
  # then auto generated domain name will be considered and account activation mail will be sent to user.
  # creating a session which will be deleted once update domain is done as the session cookie is based on domain

  def edit_domain
    @user_session = current_account.user_sessions.new(current_user)
    if @user_session.save
      current_account.schedule_account_activation_email(current_user.id) unless current_account.freshid_enabled?
      render :layout => false
      return
    else
      flash[:notice] = "Please provide valid login details!"
      return redirect_to support_login_url,
             :flash =>{:notice => t('flash.general.access_denied')}
    end
  end

  # If the user updates the domain name, account domain name, portal & forums will be updated with new domain name.

  def update_domain
    if current_account.update_default_domain_and_email_config(params["company_domain"],params["support_email"])
      current_user.reset_perishable_token!
      render json: {  :success => true, 
                      :url => signup_complete_url(:token => current_user.perishable_token, :host => current_account.full_domain)
                    }
      destroy_user_session
    else
      render json: {:success => false, :errors => "Domain name updation failed!"}
    end
  end

  # endpoint to validate domain name @edit domain page (UI)

  def validate_domain
    return unless validate_domain_name
    respond_to do |format|
      format.json { render :json => { :success => true} }
    end
  end

  def signup_validate_domain
    respond_to do |format|
      format.json do 
        head :bad_request and return if params[:domain].blank?
        new_domain = params["domain"] + "." + AppConfig['base_domain'][Rails.env]
        domain_validation_response = DomainGenerator.valid_domain?(new_domain) ? :ok : :conflict
        head domain_validation_response
      end
    end
  end

  def new_signup_free
   @signup = Signup.new(params[:signup])
   if @signup.save
      finish_signup
      respond_to do |format|
        format.html {
          render :json => { :success => true,
                            :url => signup_complete_url(:token => @signup.user.perishable_token, :host => @signup.account.full_domain),
                            :account_id => @signup.account.id  },
                            :callback => params[:callback],
                            :content_type=> 'application/javascript'
        }
        format.nmobile {

          @signup.user.deliver_admin_activation
          render :json => { :success => true, :host => @signup.account.full_domain,
                            :t => @signup.user.single_access_token,
                            :support_email => @signup.user.email
                          }
        }
      end
    else
      render :json => { :success => false, :errors => @signup.all_errors }, :callback => params[:callback]
    end    
  end

  def create    
    @account.affiliate = SubscriptionAffiliate.find_by_token(cookies[:affiliate]) unless cookies[:affiliate].blank?

    if @account.needs_payment_info?
      @address.first_name = @creditcard.first_name
      @address.last_name = @creditcard.last_name
      @account.address = @address
      @account.creditcard = @creditcard
    end
    
    if @account.save
      flash[:domain] = @account.domain
      redirect_to :action => 'thanks'
    else
      render :action => 'new'#, :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
    end
  end

  def update
    redirect_url = params[:redirect_url].presence || admin_home_index_path
    @account.account_additional_settings[:date_format] = params[:account][:account_additional_settings_attributes][:date_format] 
    @account.time_zone = params[:account][:time_zone]
    @account.helpdesk_name = params[:account][:helpdesk_name]
    @account.ticket_display_id = params[:account][:ticket_display_id]
    params[:account][:main_portal_attributes][:updated_at] = Time.now
    params[:account][:main_portal_attributes].delete(:language) if @account.features?(:enable_multilingual)
    @account.main_portal_attributes  = params[:account][:main_portal_attributes]
    @account.permissible_domains = params[:account][:permissible_domains]
    # Update bit map features
    params[:account][:bitmap_features].each  do |key, value|
      value == '0' ? @account.reset_feature(key.to_sym) : @account.set_feature(key.to_sym)
    end

    if @account.save
      enable_restricted_helpdesk(params[:enable_restricted_helpdesk])
      @account.update_attributes!(params[:account].slice(:features))
      #to prevent trusted ip middleware caching the association cache
      @account.clear_association_cache
      flash[:notice] = t(:'flash.account.update.success')
      redirect_to redirect_url
    else
      render :action => 'edit'
    end
  end  
  
  def rebrand  
    responseObj = { :status => 
        current_portal.update_attributes(params[:account][:main_portal_attributes]) }
    redirect_to admin_getting_started_index_path        
  end
  
  def cancel
    if request.post? and !params[:confirm].blank?
      response = Billing::Subscription.new.cancel_subscription(current_account)
      perform_account_cancel(params[:account_feedback]) if response
    end
  end
  
  def thanks
    redirect_to :action => "plans" and return unless flash[:domain]
    # render :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
  end
  
  def dashboard
    render :text => 'Dashboard action, engage!', :layout => true
  end
  
  def delete_logo
    current_account.main_portal.logo.destroy
    current_account.main_portal.save
    respond_to do |format|
      format.html { redirect_to :back }
      format.js { render :text => "success" }
    end
  end
  
  def delete_favicon
    current_account.main_portal.fav_icon.destroy
    current_account.main_portal.save
    
    respond_to do |format|
      format.html { redirect_to :back }
      format.js { render :text => "success" }
    end    
  end

  def manage_languages
  end

  def update_languages
    if @account.save
      flash[:notice] = t(:'flash.account.update.success')
      check_and_enable_multilingual_feature
      redirect_to edit_account_path
    else
      render :action => 'manage_languages'
    end
  end

  protected
    def multi_language_available?
      current_account.features_included?(:multi_language)
    end
    
    def check_supported_languages
      (params[:account][:account_additional_settings_attributes][:supported_languages] = []) if params[:account][:account_additional_settings_attributes][:supported_languages].nil?
    end

    def choose_layout 
      request.headers['X-PJAX'] ? 'maincontent' : 'application'
    end
  
    def load_object
      @obj = @account = current_account
    end
    
    def build_user
      @account.user = @user = User.new(params[:user])
    end
    
    def build_plan
      redirect_to :action => "plans" unless @plan = SubscriptionPlan.find_by_name(params[:plan])
      @account.plan = @plan
    end
    
    def build_primary_email_and_portal
       d_email = "support@#{@account.full_domain}"
       @account.build_primary_email_config(:to_email => d_email, :reply_email => d_email, :name => @account.name, :primary_role => true)
       @account.primary_email_config.active = true
      
      begin 
        locale = http_accept_language.compatible_language_from I18n.available_locales  
        locale = I18n.default_locale if locale.blank?
      rescue
        locale =  I18n.default_locale
      end
      portal_preferences = (@account.falcon_portal_theme_enabled?) ? default_falcon_preferences : default_preferences

      @account.build_main_portal(:name => @account.helpdesk_name || @account.name, :preferences => portal_preferences, 
                               :language => locale.to_s() , :account => @account, :main_portal => true)
     
    end
 
    def default_preferences
      HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063", :personalized_articles => true})
    end

    def default_falcon_preferences
      HashWithIndifferentAccess.new({:bg_color => "#f3f5f7",:header_color => "#ffffff", :tab_color => "#ffffff", :personalized_articles => true})
    end
  
    def redirect_url
      { :action => 'show' }
    end
    
    def load_billing
      @creditcard = ActiveMerchant::Billing::CreditCard.new(params[:creditcard])
      @address = SubscriptionAddress.new(params[:address])
    end
    
    def authorized?
      %w(new create plans canceled thanks).include?(self.action_name) || 
      (self.action_name == 'dashboard' && logged_in?) ||
      privilege?(:manage_account)
    end 
    
    def admin_selected_tab
      @selected_tab = :admin
    end   

    def validate_custom_domain_feature
      unless @account.custom_domain_enabled?
        params[:account][:main_portal_attributes][:portal_url] = nil
      end
    end
    
    def build_metrics
      # return if params[:session_json].blank?
      metrics_obj = {}
      account_obj = {}
      begin  
        account_obj[:first_referrer] = params[:first_referrer] if params[:first_referrer].present? 
        account_obj[:first_landing_url] = params[:first_landing_url] if params[:first_landing_url].present?
        account_obj[:fd_cid] = params[:fd_cid] if params[:fd_cid].present?
        if params[:user]
          account_obj[:email] = params[:user][:email]
          account_obj[:first_name] = params[:user][:first_name]
          account_obj[:last_name] = params[:user][:last_name]
          account_obj[:phone] = params[:user][:phone]
        else
          Rails.logger.info "Error while building conversion metrics. User Information is not been provided while creating an account"
        end
        if params[:session_json].present?
          metrics =  JSON.parse(params[:session_json])
          metrics_obj[:first_referrer] = params[:first_referrer]
          metrics_obj[:first_landing_url] = params[:first_landing_url]
          metrics_obj[:visits] = params[:pre_visits]
          metrics_obj[:referrer] = metrics["current_session"]["referrer"]
          metrics_obj[:landing_url] = metrics["current_session"]["url"]
          if metrics["location"].present?
            metrics_obj[:country] = metrics["location"]["countryName"]
            account_obj[:country_code] = metrics["location"]["countryCode"]
            account_obj[:city] = metrics["location"]["cityName"]
            account_obj[:source_ip] = metrics["location"]["ipAddress"]
          end
          metrics_obj[:language] = metrics["locale"]["lang"]
          if metrics["current_session"]["search"].present?
            metrics_obj[:search_engine] = metrics["current_session"]["search"]["engine"]
            metrics_obj[:keywords] = metrics["current_session"]["search"]["query"]
          end
          if metrics["device"]["is_mobile"]
            metrics_obj[:device] = "M"
          elsif  metrics["device"]["is_phone"]
            metrics_obj[:device] = "P"
          elsif  metrics["device"]["is_tablet"]
            metrics_obj[:device] = "T"
          else
            metrics_obj[:device] = "C"
          end

          metrics_obj[:browser] = metrics["browser"]["browser"]
          metrics_obj[:os] = metrics["browser"]["os"]
          metrics_obj[:offset] = metrics["time"]["tz_offset"]
          metrics_obj[:is_dst] = metrics["time"]["observes_dst"]
          metrics[:signup_method] = action
          metrics_obj[:session_json] = metrics
        else
          metrics_obj = nil
          Rails.logger.info "Error while building conversion metrics. Session json is not been provided while creating an account with email #{account_obj[:email]}"
        end
        account_obj[:source_ip] = (request.remote_ip || request.env["HTTP_X_FORWARDED_FOR"] || request.host_with_port || request.env["SERVER_ADDR"]) unless account_obj[:source_ip].present?
        return metrics_obj, account_obj
      rescue => e
        NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while building conversion metrics"}})
        Rails.logger.error("Error while building conversion metrics with session params: \n #{params[:session_json]} \n#{e.message}\n#{e.backtrace.join("\n")}")
        return nil, nil
      end
    end      

  private

    def check_sandbox?
      access_denied if current_account.sandbox?
    end

    def get_account_for_sub_domain
      base_domain = AppConfig['base_domain'][Rails.env]    
      @sub_domain = params[:account][:sub_domain]
      @full_domain = @sub_domain+"."+base_domain
      @account =  Account.find_by_full_domain(@full_domain)    
    end

    def select_latest_shard(&block)
      Sharding.select_latest_shard(&block)
    end   

    def build_signup_param
      params[:signup] = {}
      
      [:user, :account].each do |param|
        params[param].each do |key, value|
          params[:signup]["#{param}_#{key}"] = value
        end
      end
      
      params[:signup][:locale] = assign_language || http_accept_language.compatible_language_from(I18n.available_locales)
      params[:signup][:time_zone] = params[:utc_offset]
      metrics_obj, account_obj = build_metrics
      params[:signup][:metrics] = metrics_obj
      params[:signup][:account_details] = account_obj
    end

    def assign_language
      params[:account][:lang] if params.try(:[], :account).try(:[], :lang) && Language.find_by_code(params[:account][:lang]).present?
    end

    def build_signup_contact
      unless params[:user][:name]
        params[:signup][:user_name] = %(#{params[:user][:first_name]} #{params[:user][:last_name]})
        params[:signup][:contact_first_name] = params[:user][:first_name]
        params[:signup][:contact_last_name] = params[:user][:last_name]
      end
    end

    def add_account_info_to_dynamo
      AccountInfoToDynamo.perform_async({email: params[:signup][:user_email]})
    end

    def add_to_crm(account_id)
      if (Rails.env.production? or Rails.env.staging?)
        if redis_key_exists?(SIDEKIQ_MARKETO_QUEUE)
          Subscriptions::AddLead.perform_at(ThirdCRM::ADD_LEAD_WAIT_TIME.minute.from_now, { :account_id => account_id,
          :signup_id => params[:signup_id]})
        else
          Resque.enqueue_at(ThirdCRM::ADD_LEAD_WAIT_TIME.minute.from_now, Marketo::AddLead, { :account_id => account_id,
          :signup_id => params[:signup_id]})
        end
        if redis_key_exists?(FRESHSALES_ACCOUNT_SIGNUP)
          CRMApp::Freshsales::Signup.perform_at(5.minutes.from_now, { account_id: account_id,
            fs_cookie: params[:fs_cookie] })
        else
          Resque.enqueue_at(5.minute.from_now, CRM::Freshsales::Signup, { account_id: account_id,
            fs_cookie: params[:fs_cookie] })
        end
      end  
    end  

    def perform_account_cancel(feedback)
      update_crm
      deliver_mail(feedback)
      create_deleted_customers_info

      if current_account.subscription.active? or current_account.subscription_payments.present?
        add_churn
        schedule_cleanup
      else
        clear_account_data
      end

      redirect_to "#{AppConfig['app_website']}"
    end

    def update_crm
      if Rails.env.production?
        if redis_key_exists?(FRESHSALES_DELETED_CUSTOMER)
          CRMApp::Freshsales::DeletedCustomer.perform_async({ 
            account_id: current_account.id 
          })  
        else
          Resque.enqueue(CRM::AddToCRM::DeletedCustomer, { :account_id => current_account.id })
          Resque.enqueue(CRM::Freshsales::DeletedCustomer, { :account_id => current_account.id })
        end
      end
    end      

    def deliver_mail(feedback)
      SubscriptionNotifier.account_deleted(current_account, 
                                  feedback) if Rails.env.production?
    end
    
    def create_deleted_customers_info
      DeletedCustomers.create(customer_details) if current_account.subscription.active?
    end

    def add_churn
      if redis_key_exists?(SIDEKIQ_SUBSCRIPTIONS_ADD_DELETED_EVENT)
        Subscriptions::AddDeletedEvent.perform_async({ :account_id => current_account.id })
      else
        Resque.enqueue(Subscription::Events::AddDeletedEvent, { :account_id => current_account.id })
      end
    end   

    def schedule_cleanup
      current_account.subscription.update_attributes(:state => "suspended")
      jid = AccountCleanup::DeleteAccount.perform_in(14.days.from_now, {:account_id => current_account.id})
      dc = DeletedCustomers.find_by_account_id(current_account.id)
      dc.update_attributes({:job_id => jid}) if dc
    end

    def clear_account_data
      current_account.subscription.update_attributes(:state => "suspended")
      AccountCleanup::DeleteAccount.perform_async({:account_id => current_account.id})
      ::MixpanelWrapper.send_to_mixpanel(self.class.name)
    end

    def customer_details
      {
        :full_domain => "#{current_account.name}(#{current_account.full_domain})",
        :account_id => current_account.id,
        :admin_name => current_account.admin_first_name,
        :admin_email => current_account.admin_email,
        :status => FreshdeskCore::Model::STATUS[:scheduled],
        :account_info => account_info
      }
    end

    def account_info
      { 
        :plan => current_account.subscription.subscription_plan_id,
        :agents_count => current_account.agents.count,
        :tickets_count => current_account.tickets.count,
        :user_count => current_account.contacts.count,
        :account_created_on => current_account.created_at 
      }
    end      

    def enable_restricted_helpdesk action
      restricted_helpdesk = @account.restricted_helpdesk?
      if (action == "create" && !restricted_helpdesk &&  @account.features?(:twitter_signin))
        @account.features.twitter_signin.destroy
      end
      if (action == "create" && !restricted_helpdesk) ||
           (action == "destroy" && restricted_helpdesk )
        @account.features.restricted_helpdesk.safe_send(action)
      end
    end

    def check_and_enable_multilingual_feature
      return if @account.features_included?(:enable_multilingual)
      if @account.supported_languages.present?
        @account.features.enable_multilingual.create
      end
      Community::SolutionBinarizeSync.perform_async
    end

    def validate_portal_language_inclusion
      return unless params[:account][:account_additional_settings_attributes][:supported_languages].present?
      if params[:account][:account_additional_settings_attributes][:supported_languages].include?(main_portal_language)
        flash[:error] = t('accounts.multilingual_support.portal_language_inclusion')
        redirect_to manage_languages_path
      end
    end

    def main_portal_language
      return @account.language unless params[:account][:main_portal_attributes]
      params[:account][:main_portal_attributes][:language] || @account.language
    end

    def update_language_attributes
      portal_languages = (params[:account][:account_additional_settings_attributes][:additional_settings] || {})[:portal_languages] || []
      @account.main_portal_attributes = params[:account][:main_portal_attributes] unless @account.features?(:enable_multilingual)
      @account.account_additional_settings[:supported_languages] = params[:account][:account_additional_settings_attributes][:supported_languages]
      @account.account_additional_settings.additional_settings[:portal_languages] = portal_languages
    end

    def validate_feature_params
      allowed_features = @account.subscription.non_sprout_plan? ? ["forums"] : []
      if params[:account] && params[:account][:features]
        params[:account][:features] = params[:account][:features].slice(*allowed_features)
      end
    end

    def save_account_sign_up_params account_id, args = {}
      key = ACCOUNT_SIGN_UP_PARAMS % {:account_id => account_id}
      set_others_redis_key(key,args.to_json,3888000)
    end

    def mark_new_account_setup
      @signup.account.mark_new_account_setup_and_save
    end

    def finish_signup
      @signup.user.reset_perishable_token!
      save_account_sign_up_params(@signup.account.id, params[:signup].merge({"signup_method" => action}))
      add_account_info_to_dynamo
      set_account_onboarding_pending
      mark_new_account_setup
      add_to_crm(@signup.account.id)
    end

    def set_additional_signup_params
      params["signup"]["account_name"] = @domain_generator.domain_name
      params["signup"]["account_domain"] = @domain_generator.subdomain
      params["signup"]["contact_first_name"] = @domain_generator.email_name
      params["signup"]["contact_last_name"] = @domain_generator.email_name
    end

    def check_for_existing_accounts
      accounts_count = AdminEmail::AssociatedAccounts.find(params["user"]["email"]).length
      return if (@domain_generator.email_company_name == AppConfig["app_name"].downcase) || accounts_count == 0 || (accounts_count < Signup::MAX_ACCOUNTS_COUNT && params["force"] == "true")
      status_code = accounts_count >= Signup::MAX_ACCOUNTS_COUNT ?  Signup::SIGNUP_RESPONSE_STATUS_CODES[:too_many_requests] : Signup::SIGNUP_RESPONSE_STATUS_CODES[:precondition_failed]
      render :json => {:success => false, :accounts_count => accounts_count, :errors => [I18n.t("activerecord.errors.messages.exceeded_email")]}, :callback => params[:callback], :status => status_code
    end

    def validate_signup_email
      params["user"]["email"].downcase!
      @domain_generator = DomainGenerator.new(params["user"]["email"])
      unless @domain_generator.valid?
        respond_to do |format|
          format.json {
            render :json => { :success => false, 
              :errors => @domain_generator.errors[:email]}, 
              :status => :unprocessable_entity  
          }
        end
      end
    end

    # Do not allow users to perform edit/validate/update domain if account is verified
    def account_unverified?
      access_denied if current_account.verified?
    end

    def ensure_proper_user
      @current_user = current_user || current_account.users.find_by_perishable_token(
          params[:perishable_token]) unless params[:perishable_token].blank?
      unless (current_user && current_user.privilege?(:manage_account))
        flash[:notice] = t('flash.general.access_denied')
        redirect_to support_login_path
      end
    end

    # Once update domain is executed (once user updates the domain name successfully),
    # deleting the job scheduled for auto-enter to dashboard after 10min.

    def kill_account_activation_email_job
      current_account.kill_account_activation_email_job
    end

    # Scheduled job will be cancelled(deleted) when a user submits the form within 10m.
    # Suppose, if the user submits form after 10 min, he will be taken to dashboard with 
    # domain name which was auto-generated.Even if user enters new domain name in the 
    # edit domain page after 10 min, it will not be considered.

    def check_activation_mail_job_status
      job_id = get_others_redis_key(current_account.account_activation_job_status_key)
      job = Sidekiq::ScheduledSet.new.find_job(job_id)

      if job.present?
        respond_to do |format|
          format.html { render :layout => false } #skipping email scheduling and session creation in edit_domain if mail is already enqueued
          format.json {} #do nothing for update_domain
        end
      else
        respond_to do |format|
          format.html do 
            if current_user_session
              flash[:notice] = t("accounts.edit_domain.account_url_defaulted")
              redirect_to "/"
            end
          end
          format.json do 
            render json: {  :success => false, 
                            :url => root_url(:host => current_account.full_domain)},
                            :status => :request_timeout
            return
          end
        end
      end
    end      

    # When user submits edit domain form & does not change domain name, taking user directly to dashboard.
    # If user changes the domain name, validate and proceed with update_domain.
    # method is also used for on blur domain validation

    def validate_domain_name
      downcase_domain_params
      new_domain = params["company_domain"] + "." + AppConfig['base_domain'][Rails.env]

      unless valid_domain?(new_domain)
        respond_to do |format|
          format.json {
            render(:json => { :success => false,
                              :errors => "Domain already exists"},
                              :status => :unprocessable_entity) and return false
          }
        end
      end
      true
    end

    def downcase_domain_params
      ["company_domain", "support_email"].each do |param_name|
        params[param_name].downcase! if params[param_name]
      end
    end

    def valid_domain?(new_domain)
      return true if (new_domain == current_account.full_domain)
      DomainGenerator.valid_domain?(new_domain)
    end

    def destroy_user_session
      current_user_session.destroy unless current_user_session.nil?
      @current_user_session = @current_user = nil
    end
end
