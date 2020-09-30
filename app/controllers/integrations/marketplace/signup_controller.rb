class Integrations::Marketplace::SignupController < ApplicationController
  include Integrations::Marketplace::LoginHelper
  include Integrations::Marketplace::ProxyAuthHelper

  layout :choose_layout

  skip_filter :select_shard, :only => [:create_account]
  around_filter :select_latest_shard, :only => [:create_account]

  skip_before_filter :check_privilege, :verify_authenticity_token, :set_current_account, :check_account_state,
                     :set_time_zone, :check_day_pass_usage, :set_locale, :check_session_timeout

  before_filter :initialize_attr, :check_remote_integrations_mapping
  before_filter :load_account, :only => [:associate_account, :associate_account_using_proxy]
  before_filter :build_signup_param, :only => [:create_account]

  UNVERIFIED_EMAIL_APPS = %w(quickbooks)
  def associate_account
    @account.make_current
    if @email_not_reqd
      login_user = nil
    else
      login_user = get_user(@account, @email)
    end
    request_params = params['request_params'].merge({:remote_id => @remote_id})
    if login_user.present? && UNVERIFIED_EMAIL_APPS.exclude?(@app_name)
      verify_user_and_redirect(login_user)
    elsif proxy_auth_app?(@app_name) && login_user.blank?
      flash.now[:notice] = t(:'flash.g_app.use_admin_cred')
      render "google_signup/proxy_auth"
    else
      redirect_url = get_redirect_url(@app_name, @account, request_params)
      redirect_to redirect_url
    end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      redirect_url = get_redirect_url(@app_name, @account, request_params)
      redirect_to redirect_url
  end

  def associate_account_using_proxy
    @account.make_current
    @check_session = @account.user_sessions.new(params[:user_session])
    if @check_session.save
      auth_user = @check_session.user
      sso_redirect(auth_user)
    else
      flash.now[:notice] = t(:'flash.general.insufficient_privilege.admin')
      render "google_signup/signup_google_error"
    end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      flash.now[:error] = t(:'flash.g_app.domain_restriction')
      render "google_signup/signup_google_error"
  end

  def create_account
    @signup = Signup.new(params[:signup])
    if @signup.save
      @signup.user.reset_perishable_token!
      @signup.user.deliver_admin_activation
      @account = @signup.account
      add_to_crm
      update_remote_integrations_mapping(@app_name, @remote_id, @account, @signup.user)
      set_redis_and_redirect(@app_name, @account, @remote_id, @email, @operation)
      mark_new_account_setup
    else
      @account = @signup.account
      @user = @signup.user
      @call_back_url = params[:call_back]
      render 'integrations/marketplace/associate_account'
    end
  end

  protected

  def choose_layout
    'signup_google'
  end

  private

  def select_shard(&block)
    full_domain
    if @sub_domain.blank?
      flash.now[:error] = t(:'flash.g_app.no_subdomain')
      get_account_and_user_new
      render 'integrations/marketplace/associate_account' and return
    end

    Sharding.select_shard_of(full_domain) do
      yield
    end
  end

  def select_latest_shard(&block)
    Sharding.select_latest_shard(&block)
  end

  def add_to_crm
    if Rails.env.production?
      Subscriptions::AddLead.perform_at(3.minute.from_now, { :account_id => @signup.account.id, 
        :signup_id => params[:signup_id], :fs_cookie => params[:fs_cookie] })
    end
  end

  def build_signup_param
    params[:signup] = {}
    params[:signup][:direct_signup] = true
    [:user, :account].each do |param|
      params[param].each do |key, value|
        params[:signup]["#{param}_#{key}"] = value
      end
    end

    params[:signup][:locale] = http_accept_language.compatible_language_from(I18n.available_locales)
    params[:signup][:time_zone] = params[:utc_offset]
    params[:signup][:metrics] = build_metrics
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

  def initialize_attr
    @name = params[:user][:name]
    @email = params[:user][:email]
    @remote_id = params[:user][:remote_id]
    @uid = params[:user][:uid]
    if params[:request_params].present?
      @operation = params[:request_params][:operation]
      @app_name = params[:request_params][:app_name]
      @email_not_reqd = params[:request_params][:email_not_reqd].to_bool
    end
  end

  def check_remote_integrations_mapping
    if find_account_by_remote_id(@remote_id, @app_name)
      render :template => 'integrations/marketplace/error', :locals => { :error_type => 'already_exist' }
    end
  end

  def load_account
    @account = Account.find_by_full_domain(full_domain)
    if @account.nil?
      render :template => 'integrations/marketplace/error', :locals => { :error_type => 'account_not_exist' }
    end
  end

  def full_domain
    base_domain = AppConfig['base_domain'][Rails.env]    
    @sub_domain = params[:account][:domain]
    @full_domain = @sub_domain + "." + base_domain
  end

  def get_account_and_user_new
    @account = Account.new(:domain => params[:account][:domain], :name => params[:account][:name])
    @user = @account.users.new(:email => params[:user][:email], :name => params[:user][:name])
  end

  def mark_new_account_setup
    @signup.account.mark_new_account_setup_and_save
  end
end
