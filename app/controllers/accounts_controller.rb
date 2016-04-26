class AccountsController < ApplicationController

  include ModelControllerMethods
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Redis::DisplayIdRedis
  include MixpanelWrapper
  
  layout :choose_layout 
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:check_domain, :new_signup_free,
                     :create, :rebrand, :dashboard, :rabbitmq_exchange_info]

  skip_before_filter :set_locale, :except => [:cancel, :show, :edit]
  skip_before_filter :set_time_zone, :set_current_account,
    :except => [:cancel, :edit, :update, :delete_logo, :delete_favicon, :show]
  skip_before_filter :check_account_state
  skip_before_filter :redirect_to_mobile_url
  skip_before_filter :check_day_pass_usage, :except => [:cancel, :edit, :update, :delete_logo, :delete_favicon, :show]
  skip_filter :select_shard, :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo]
  skip_before_filter :ensure_proper_protocol, :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo]
  skip_before_filter :determine_pod, :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo]

  around_filter :select_latest_shard, :except => [:update,:cancel,:edit,:show,:delete_favicon,:delete_logo]

  before_filter :build_user, :only => [ :new, :create ]
  before_filter :build_metrics, :only => [ :create ]
  before_filter :load_billing, :only => [ :show, :new, :create, :payment_info ]
  before_filter :build_plan, :only => [:new, :create]
  before_filter :admin_selected_tab, :only => [:show, :edit, :cancel ]
  before_filter :validate_custom_domain_feature, :only => [:update]
  before_filter :build_signup_param, :only => [:new_signup_free]
  before_filter :build_signup_contact, :only => [:new_signup_free]
  before_filter :check_supported_languages, :only =>[:update], :if => :dynamic_content_available?
  before_filter :set_native_mobile, :only => [:new_signup_free]

  
  def show
  end   
   
  def edit
    @supported_languages_list = current_account.account_additional_settings.supported_languages 
    @ticket_display_id = current_account.get_max_display_id
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
   
  def new_signup_free
   @signup = Signup.new(params[:signup])
   
   if @signup.save
   @signup.account.agents.first.user.reset_perishable_token! 
      add_to_crm
      respond_to do |format|
        format.html {
          render :json => { :success => true,
                            :url => signup_complete_url(:token => @signup.account.agents.first.user.perishable_token, :host => @signup.account.full_domain),
                            :account_id => @signup.account.id  },
                            :callback => params[:callback]
        }
        format.nmobile {

          @signup.account.agents.first.user.deliver_admin_activation
          render :json => { :success => true, :host => @signup.account.full_domain,
                            :t => @signup.account.agents.first.user.single_access_token,
                            :support_email => @signup.account.agents.first.user.email
                          }
        }
      end
    else
      render :json => { :success => false, :errors => (@signup.account.errors || @signup.errors).fd_json }, :callback => params[:callback] 
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
    @account.account_additional_settings[:supported_languages] = params[:account][:account_additional_settings_attributes][:supported_languages] if dynamic_content_available?
    @account.account_additional_settings[:date_format] = params[:account][:account_additional_settings_attributes][:date_format] 
    @account.time_zone = params[:account][:time_zone]
    @account.ticket_display_id = params[:account][:ticket_display_id]
    params[:account][:main_portal_attributes][:updated_at] = Time.now
    @account.main_portal_attributes = params[:account][:main_portal_attributes]
    if @account.save
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

  protected
    def dynamic_content_available?
      current_account.features?(:dynamic_content)
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
      @account.build_main_portal(:name => @account.helpdesk_name || @account.name, :preferences => default_preferences, 
                               :language => locale.to_s() , :account => @account, :main_portal => true)
     
    end
 
    def default_preferences
      HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063"})
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
      unless @account.features?(:custom_domain)
        params[:account][:main_portal_attributes][:portal_url] = nil
      end
    end
    
    def build_metrics
      return if params[:session_json].blank?
      
      begin  
        metrics =  JSON.parse(params[:session_json])
        metrics_obj = {}

        metrics_obj[:referrer] = metrics["current_session"]["referrer"]
        metrics_obj[:landing_url] = metrics["current_session"]["url"]
        metrics_obj[:first_referrer] = params[:first_referrer]
        metrics_obj[:first_landing_url] = params[:first_landing_url]
        metrics_obj[:country] = metrics["location"]["countryName"] unless metrics["location"].blank?
        metrics_obj[:language] = metrics["locale"]["lang"]
        metrics_obj[:search_engine] = metrics["current_session"]["search"]["engine"]
        metrics_obj[:keywords] = metrics["current_session"]["search"]["query"]
        metrics_obj[:visits] = params[:pre_visits]

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
        metrics_obj[:session_json] = metrics
        metrics_obj
      rescue => e
        NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while building conversion metrics"}})
        Rails.logger.error("Error while building conversion metrics with session params: \n #{params[:session_json]} \n#{e.message}\n#{e.backtrace.join("\n")}")
        nil
      end
    end      

  private

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
      
      params[:signup][:locale] = http_accept_language.compatible_language_from(I18n.available_locales)
      params[:signup][:time_zone] = params[:utc_offset]
      params[:signup][:metrics] = build_metrics
    end

    def build_signup_contact
      unless params[:user][:name]
        params[:signup][:user_name] = %(#{params[:user][:first_name]} #{params[:user][:last_name]})
        params[:signup][:contact_first_name] = params[:user][:first_name]
        params[:signup][:contact_last_name] = params[:user][:last_name]
      end
    end

    def add_to_crm
      if (Rails.env.production? or Rails.env.staging?)
        Resque.enqueue_at(3.minute.from_now, Marketo::AddLead, { :account_id => @signup.account.id, 
          :signup_id => params[:signup_id] })
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
      Resque.enqueue(CRM::AddToCRM::DeletedCustomer, { :account_id => current_account.id })
    end      

    def deliver_mail(feedback)
      SubscriptionNotifier.account_deleted(current_account, 
                                  feedback) if Rails.env.production?
    end
    
    def create_deleted_customers_info
      DeletedCustomers.create(customer_details) if current_account.subscription.active?
    end

    def add_churn
      Resque.enqueue(Subscription::Events::AddDeletedEvent, { :account_id => current_account.id }) 
    end   

    def schedule_cleanup
      current_account.subscription.update_attributes(:state => "suspended")

      Resque.enqueue_at(14.days.from_now, Workers::ClearAccountData, 
                                    { :account_id => current_account.id })
    end

    def clear_account_data
      Resque.enqueue(Workers::ClearAccountData, { :account_id => current_account.id })
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

end
