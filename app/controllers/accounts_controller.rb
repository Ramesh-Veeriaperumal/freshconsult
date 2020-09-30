class AccountsController < ApplicationController

  include Admin::AdvancedTicketing::FieldServiceManagement::Util
  include ModelControllerMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::TicketsRedis
  include Redis::DisplayIdRedis
  include Onboarding::OnboardingRedisMethods
  include AccountConstants
  include AccountsHelper

  layout :choose_layout 

  skip_before_filter :check_privilege, :verify_authenticity_token, only: [:check_domain, :new_signup_free, :email_signup, :signup_validate_domain,
                                                                          :create, :rebrand, :dashboard, :rabbitmq_exchange_info, :edit_domain,
                                                                          :anonymous_signup]

  skip_before_filter :set_locale, except: [:cancel, :show, :edit, :manage_languages, :edit_domain, :anonymous_signup_complete]
  skip_before_filter :set_time_zone, :set_current_account, :check_session_timeout,
    except: [:cancel, :edit, :update, :delete_logo, :delete_favicon, :show, :manage_languages, :update_languages, :edit_domain, :validate_domain, :update_domain, :anonymous_signup_complete]
  skip_before_filter :check_account_state
  skip_before_filter :redirect_to_mobile_url
  skip_before_filter :check_day_pass_usage, 
    except: [:cancel, :edit, :update, :delete_logo, :delete_favicon, :show, :manage_languages, :update_languages, :anonymous_signup_complete]
  skip_filter :select_shard, 

    except: [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo, :manage_languages, :update_languages, :edit_domain, :validate_domain, :update_domain, :anonymous_signup_complete]
  skip_before_filter :ensure_proper_protocol, :ensure_proper_sts_header,

    except: [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo, :manage_languages, :update_languages, :anonymous_signup_complete]
  skip_before_filter :determine_pod, 
    except: [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo, :manage_languages, :update_languages, :anonymous_signup_complete]
  skip_after_filter :set_last_active_time

  around_filter :select_latest_shard, except: [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo,:manage_languages,:update_languages, :edit_domain, :validate_domain, :update_domain, :anonymous_signup_complete]

  before_filter :anonymous_signup_enabled?, :build_anonymous_signup_params, only: [:anonymous_signup]
  before_filter :validate_signup_email, only: [:email_signup, :new_signup_free]
  before_filter :check_for_existing_accounts, only: [:email_signup, :new_signup_free], :if => :whitelisted_email?

  before_filter :ensure_proper_user, :only => [:edit_domain]
  before_filter :check_activation_mail_job_status, :only => [:edit_domain, :update_domain], :unless => :freshid_integration_enabled?
  before_filter :validate_domain_name, :only => [:update_domain]
  after_filter  :kill_account_activation_email_job, :only => [:update_domain], :unless => :freshid_integration_enabled?
  before_filter :build_user, :only => [ :new, :create ]
  before_filter :build_metrics, :only => [ :create ]
  before_filter :load_billing, :only => [ :show, :new, :create, :payment_info ]
  before_filter :build_plan, :only => [:new, :create]
  before_filter :check_sandbox?, :only => [:cancel]
  before_filter :admin_selected_tab, :only => [:show, :edit, :cancel, :manage_languages  ]
  before_filter :validate_custom_domain_feature, :only => [:update]
  before_filter :build_signup_param, :build_signup_contact, only: [:new_signup_free, :email_signup, :anonymous_signup]
  before_filter :check_supported_languages, :only =>[:update], :if => :multi_language_available?
  before_filter :set_native_mobile, only: :new_signup_free
  before_filter :set_additional_signup_params, only: [:email_signup, :anonymous_signup]
  before_filter :validate_feature_params, :only => [:update]
  before_filter :update_language_attributes, :only => [:update_languages]
  before_filter :validate_portal_language_inclusion, :only => [:update_languages]
  before_filter(:only => [:manage_languages]) { |c| c.requires_feature :multi_language }
  before_filter :block_url_name, only: [:email_signup, :new_signup_free], :if => :params_contain_url
  
  def show
  end   

  def block_url_name
    respond_to do |format|
      format.json {
        render :json => { :success => false, :errors => [t("flash.signup.name_as_url")]}, :callback => params[:callback], :status => 422
      }
    end
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
    render :json => { :account_name => true }, :callback => params[:callback]
  end

  def email_signup
    @signup = Signup.new(params[:signup])
    @signup.account.fs_cookie_signup_param = params[:fs_cookie]
    if @signup.save
      enable_field_service_management if fsm_signup_page?
      finish_signup
      respond_to do |format|
        format.json {
          render :json => { :success => true,
                            :url => email_signup_redirect_url,
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

  def anonymous_signup
    @signup = Signup.new(params[:signup])
    @signup.account.is_anonymous_account = true
    if @signup.save
      mark_account_as_anonymous
      enable_field_service_management if fsm_signup_page?
      finish_signup
      render json: { success: true,
        url: signup_complete_url(token: @signup.user.perishable_token, host: @signup.account.full_domain),
        account_id: @signup.account.id },
        callback: params[:callback],
        content_type: 'application/javascript'
    else
      respond_to do |format|
        format.json render json: { success: false, errors: @signup.all_errors }, callback: params[:callback]
      end
    end
  end

  # Enables user to edit domain name & support email.
  # Scheduling a job for 10 min. If the user did not submit the form before the scheduled time,
  # then auto generated domain name will be considered and account activation mail will be sent to user.
  # creating a session which will be deleted once update domain is done as the session cookie is based on domain

  def edit_domain
    new_freshid_signup = @current_user.active = true unless @current_user.active_freshid_agent?
    @user_session = current_account.user_sessions.new(@current_user)
    if @user_session.save
      @current_user.reload
      @current_user.primary_email.update_attributes({verified: false}) if new_freshid_signup
      @current_account.schedule_account_activation_email(@current_user.id) unless freshid_integration_enabled?
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

  def assign_precreated_account
    input_params = params[:signup].except(:direct_signup)
    input_params.merge!(account: Account.current, user: User.current)
    @signup = PrecreatedSignup.new(input_params)
    @signup.account.fs_cookie_signup_param = params[:fs_cookie]
    @signup.save!
    @signup.execute_post_signup_steps
    true
  rescue StandardError => e
    Rails.logger.error "Error in mapping precreated account - error - #{e.message} backtrace - #{e.backtrace}"
    NewRelic::Agent.notice_error(e, custom_params: { description: "Error occoured while mapping precreated account for Account #{Account.current.id}" })
    Account.reset_current_account
    User.reset_current_user
  ensure
    AccountCreation::PrecreateAccounts.perform_async(precreate_account_count: 1, shard_name: ActiveRecord::Base.current_shard_selection.shard.to_s)
  end

  def new_signup_free
    account_id = fetch_precreated_account
    account_created = assign_precreated_account if account_id.present?
    unless account_created
      set_additional_signup_params
      @signup = Signup.new(params[:signup])
      @signup.account.fs_cookie_signup_param = params[:fs_cookie]
      account_created = @signup.save
    end

    if account_created
      enable_field_service_management if fsm_signup_page?
      finish_signup
      mark_perishable_token_expiry(@signup.account, @signup.user)
      if is_aloha_signup?
        render :json => fetch_product_signup_response, :content_type => 'application/json'
        return
      end
      respond_to do |format|
        format.json {
          render :json => { :success => true,
                            :spam_score => fetch_spam_score,
                            :product_signup_response => fetch_product_signup_response,
                            :url => signup_complete_url(:token => @signup.user.perishable_token, :host => @signup.account.full_domain),
                            :account_id => @signup.account.id  },
                            :callback => params[:callback],
                            :content_type=> 'application/javascript'
        }
        format.html {
          render :json => { :success => true,
                            :spam_score => fetch_spam_score,
                            :product_signup_response => fetch_product_signup_response,
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
    @account.account_additional_settings.notes_order = params[:oldest_on_top] if current_account.reverse_notes_enabled? && params[:oldest_on_top].present?
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

  def fetch_spam_score
    # we are sending default values for now. This will be updated while building Aloha flow.
    key = ACCOUNT_SIGN_UP_PARAMS % { :account_id => @signup.account.id }
    json_response = get_others_redis_key(key)
    parsed_response = JSON.parse(json_response) if json_response.present?
    parsed_response = { 'api_response' => {} } unless parsed_response && parsed_response['api_response']
    {
      'Status': parsed_response['api_response']['status'],
      'RequestId': nil,
      'Results': {
        'RISK LEVEL': parsed_response['api_response']['RISK LEVEL'],
        'RISK SCORE': 0,
        'REASON': []
      }
    }
  end

  def fetch_product_signup_response
    acc_additional_settings = @signup.account.account_additional_settings
    perishable_token = @signup.user.perishable_token
    bundle_id = acc_additional_settings.present? ? acc_additional_settings.additional_settings[:bundle_id] : nil
    bundle_name = acc_additional_settings.present? ? acc_additional_settings.additional_settings[:bundle_name] : nil
    {
      redirect_url: signup_complete_url(token: perishable_token, host: @signup.account.full_domain),
      account: {
        id: @signup.account.id,
        domain: @signup.account.full_domain,
        name: @signup.account.name,
        locale: nil,
        timezone: nil,
        alternate_url: '',
        description: ''
      },
      misc: {
        bundle_name: bundle_name,
        bundle_id: bundle_id,
        account_domain: @signup.account.full_domain,
        token: perishable_token
      }
    }
  end

  def anonymous_signup_complete
    if current_user.nil?
      flash[:notice] = 'Please provide valid login details!!'
      redirect_to login_url
    elsif current_user.active_freshid_agent?
      cookies[:return_to] = '/a/getstarted'
      current_user.reset_persistence_token!
      redirect_to support_login_url(params: { new_account_signup: true, signup_email: current_user.email })
    else
      redirect_to '/a/getstarted'
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
          metrics =  params[:session_json].is_a?(Hash) ? params[:session_json] : JSON.parse(params[:session_json])
          metrics_obj[:first_referrer] = params[:first_referrer]
          metrics_obj[:first_landing_url] = params[:first_landing_url] || params[:first_landing_page]
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
          metrics[:signup_method] = signup_type_from_action(metrics_obj)
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

    def mark_perishable_token_expiry(account, user)
      account.mark_authorization_code_expiry
      user.mark_perishable_token_expiry
    end

    def render_signup_error(errors)
      render json: { success: false, errors: errors }, status: :unprocessable_entity
    end

    def params_contain_url
      contains = [:user_first_name, :user_last_name, :user_email, :user_phone, :account_name, :account_domain].any? do |key| 
        value = params[:signup][key].to_s
        (value.include?("http://") || value.include?("https://"))
      end
      contains ||= [:user_first_name, :user_last_name].any? {|key| params[:signup][key].to_s.include?(".")}
      Rails.logger.info "Failing Signup" if contains
      contains
    end

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
      if FreshopsSubdomains.include?(request.subdomain) && Sharding.all_shards.include?(params[:user][:shard_name])
        Sharding.run_on_shard(params[:user][:shard_name], &block)
      else
        Sharding.select_latest_shard(&block)
      end
    end

    def build_signup_param
      assign_account_params
      assign_signup_params
      assign_freshid_attributes
      metrics_obj, account_obj = build_metrics
      params[:signup][:metrics] = metrics_obj
      params[:signup][:account_details] = account_obj
      params[:signup][:direct_signup] = true
    end

    def assign_account_params
      params[:account] = {} unless params[:account]
      if params[:misc].present?
        params[:account][:name] = params[:misc][:account_name]
        params[:account][:lang] = params[:misc][:account_lang]
      end
    end

    def assign_signup_params
      params[:signup] = {}
      IGNORE_SIGNUP_PARAMS.each { |p| params[:user].delete p }
      [:user, :account].each do |param|
        params[param].each do |key, value|
          params[:signup]["#{param}_#{key}"] = value
        end
      end
      
      params[:signup][:locale] = assign_language || http_accept_language.compatible_language_from(I18n.available_locales)
      params[:signup][:time_zone] = params[:utc_offset]
      params[:signup][:referring_product] = params[:misc][:referring_product] if params[:misc].present?
    end

    def assign_freshid_attributes
      org_details = params[:organisation].present? && params[:organisation][:domain] && params[:organisation][:id]
      params[:signup][:aloha_signup] = false
      if org_details
        params[:signup][:freshid_user] = params[:user]
        params[:signup][:organisation] = params[:organisation]
        params[:signup][:aloha_signup] = true
      else
        params[:signup][:org_id] = params[:org_id]
      end
      if params[:join_token].present?
        params[:signup][:fresh_id_version] = params[:fresh_id_version].presence || Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2
        params[:signup][:join_token] = params[:join_token]
      end
      if params[:misc].present? && params[:misc][:bundle_id].present? && params[:misc][:bundle_name].present?
        params[:signup][:bundle_id] = params[:misc][:bundle_id]
        params[:signup][:bundle_name] = params[:misc][:bundle_name]
      end
      Rails.logger.info "Aloha signup :: #{params[:signup][:aloha_signup]}. Bundle signup :: #{params[:signup][:bundle_id].present?}"
    end

    def is_aloha_signup?
      params[:signup][:aloha_signup]
    end

    def omni_signup?
      params[:signup][:bundle_id].present? && params[:signup][:bundle_name].present?
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

    def perform_account_cancel(feedback)
      unless current_account.anonymous_account?
        current_account.update_crm
        current_account.send_account_deleted_email(feedback)
      end
      current_account.create_deleted_customers_info
      if current_account.free_or_active_account?
        current_account.add_churn
        current_account.schedule_cleanup
      else
        current_account.clear_account_data
      end

      redirect_to "#{AppConfig['app_website']}"
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
      save_account_sign_up_params(@signup.account.id, params[:signup].merge('signup_method' => action, 'fs_cookie' => params[:fs_cookie], 'signup_id' => params[:signup_id]))
      unless @signup.account.anonymous_account?
        add_account_info_to_dynamo(params[:signup][:user_email])
        add_to_crm(@signup.account.id, params)
      end
      set_account_onboarding_pending
      mark_new_account_setup
      AddEventToFreshmarketer.perform_async(event: ThirdCRM::FRESHMARKETER_EVENTS[:fdesk_event], event_name: FM_TRIAL_EVENT_NAME)
    end

    def set_additional_signup_params
      signup_params = params['signup']
      email_name = @domain_generator.email_name
      signup_params['account_name']        ||= @domain_generator.domain_name
      signup_params['account_domain']      ||= @domain_generator.subdomain
      signup_params['contact_first_name']  ||= email_name
      signup_params['contact_last_name']   ||= email_name
    end

    def check_for_existing_accounts
      return if normal_full_signup?
      params[:force] = 'true' if params[:action] != 'email_signup'
      accounts_count = AdminEmail::AssociatedAccounts.find(params["user"]["email"]).length
      return if (@domain_generator.email_company_name == AppConfig['app_name'].downcase) || accounts_count.zero? || (accounts_count < Signup::MAX_ACCOUNTS_COUNT && params['force'] == 'true')
      status_code = accounts_count >= Signup::MAX_ACCOUNTS_COUNT ?  Signup::SIGNUP_RESPONSE_STATUS_CODES[:too_many_requests] : Signup::SIGNUP_RESPONSE_STATUS_CODES[:precondition_failed]
      render :json => {:success => false,
        :accounts_count => accounts_count,
        :errors => [I18n.t("activerecord.errors.messages.exceeded_email")]},
        :callback => params[:callback], :status => status_code
    end

    def validate_signup_email
      render_signup_error([t('flash.general.invalid_email')]) && return if params['user'].blank? || params['user']['email'].blank?
      params['user']['email'].downcase!
      @domain_generator = DomainGenerator.new(params['user']['email'])
      unless @domain_generator.valid?
        render_signup_error(@domain_generator.errors[:email])
      end
    rescue StandardError => e
      Rails.logger.error "Error occoured while validating signup email #{e.inspect}"
      render_signup_error([t('flash.general.invalid_email')])
    end

    def anonymous_signup_enabled?
      unless redis_key_exists?(ANONYMOUS_ACCOUNT_SIGNUP_ENABLED)
        render(json: { error: :access_denied }, status: 403)
        return
      end
    end

    def build_anonymous_signup_params
      params[:user] = {
        email: generate_demo_email,
        first_name: 'Demo',
        last_name: 'Account'
      }
      params[:account] = { user: params[:user] }
      @domain_generator = DomainGenerator.new(params[:user][:email], [], action_name)
    end

    def generate_demo_email
      current_time = (Time.now.utc.to_f * 1000).to_i
      "#{ANONYMOUS_EMAIL}#{current_time}@example.com"
    end

    def signup_type_from_action(metrics_obj)
      current_action = params[:action]
      if metrics_obj[:device] != 'C'
        'mobile'
      elsif current_action == 'new_signup_free' && !normal_full_signup?
        'domain_less_signup'
      else
        current_action
      end
    end

    def normal_full_signup?
      account_params = params['account']
      account_params && account_params.key?(:domain)
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

    def email_signup_redirect_url
      signup_complete_url(:token => @signup.user.perishable_token, :host => @signup.account.full_domain)
    end

    def mark_account_as_anonymous
      @signup.account.reload
      @signup.account.account_additional_settings.mark_account_as_anonymous
    end

    def whitelisted_email?
      !ismember?(INCREASE_DOMAIN_FOR_EMAILS, params["user"]["email"])
    end

    def fsm_signup_page?
      conversion_metric = @signup.account.conversion_metric
      return false if conversion_metric.nil? || conversion_metric.landing_url.nil?

      fsm_sign_up_pages = get_all_members_in_a_redis_set(FSM_SIGN_UP_ENABLED_PAGES_LIST)
      fsm_sign_up_pages.any? { |page_url| conversion_metric.landing_url.start_with?(page_url) }
    end

    def enable_field_service_management
      account = @signup.account.reload
      account.add_feature(:field_service_management)
      perform_fsm_operations(fsm_signup_flow: true)
    end
end
