class Integrations::Marketplace::LoginController < ApplicationController
  include Integrations::Marketplace::LoginHelper

  layout :choose_layout

  skip_before_filter :check_privilege, :only => [:login, :tryout]
  skip_before_filter :set_current_account, :verify_authenticity_token, :check_account_state,
    :set_time_zone, :check_day_pass_usage, :set_locale, :only => [:tryout]

  before_filter :get_user_from_redis, :only => [:login]

  def login
    if @login_user.nil? || @login_user.deleted
      user_deleted
    else
      create_user_session(@login_user)
    end
  end

  def tryout
    initialize_attr({'email_not_reqd' => true})
    render 'integrations/marketplace/associate_account'
  end

  protected

  def choose_layout
    'signup_google'
  end

  private

  def initialize_attr(data)
    @email_not_reqd = data['email_not_reqd'] || false
    @email = data['email']
    @remote_id = data['remote_id']
    @name = data['user_name']
    @account = Account.new(:domain => data['domain'], :name => data['account_name'])
    @user = @account.users.new(:email => @email, :name => @name)
    @operation = params[:operation] || ''
    @app_name = params[:app] || data['app'] || ''
    @account_id = nil
    @remote_integ_mapping = get_remote_integ_mapping(@remote_id, @app_name)
    if @remote_integ_mapping.present?
      @account_id = @remote_integ_mapping.account_id
    end
  end

  def map_remote_user
    if (@email || @email_not_reqd) && @remote_id
      if login_account.present?
        login_account.make_current
        if @email_not_reqd
          @domain_user = nil
        else
          @domain_user = get_user(login_account, @email)
        end
        if @domain_user.nil?
          redirect_url = get_redirect_url(@app_name, login_account, {'operation' => params[:operation], 'remote_id' => @remote_id})
          redirect_to redirect_url and return
        elsif @remote_integ_mapping.configs.present? && @remote_integ_mapping.configs[:user_id].to_i != @domain_user.id
          render :template => 'integrations/marketplace/error', :locals => { :error_type => 'already_exist' } and return
        end
        activate_user_and_redirect
      else
        render 'integrations/marketplace/associate_account'
      end
    else
      logger.debug "Authentication failed....delivering error page"
      raise ActionController::RoutingError, "Not Found"
    end
  end

  def login_account
    return @login_account if defined?(@login_account)
    if @account_id.nil?
      @remote_integ_mapping = get_remote_integ_mapping(@remote_id, @app_name)
      if @remote_integ_mapping.present?
        @account_id = @remote_integ_mapping.account_id
      end
    end
    @login_account = Account.find(@account_id) if @account_id
  end

  def activate_user_and_redirect
    verify_user
    set_redis_and_redirect(params['app'], login_account, @remote_id, @email, @operation)
  end

  def verify_user
    if !@domain_user.active?
      make_user_active(@domain_user)
    end
  end

  def get_user_from_redis
    redis_oauth_key = "#{params['app_name']}_SSO:#{params['remote_id']}:#{params['timestamp']}"
    email = get_others_redis_key(redis_oauth_key)
    @login_user = get_user(current_account, email)
    remove_others_redis_key(redis_oauth_key)
  end

   def create_user_session(user)
     @user_session = current_account.user_sessions.new(user)
     @user_session.web_session = true unless is_native_mobile?
     redirect_url = get_redirect_url params[:app_name], current_account, params
     if @user_session.save
       return unless grant_day_pass
       if user.privilege?(:admin_tasks)
         redirect_to redirect_url
      else
        redirect_back_or_default('/')
       end
     else
       redirect_to login_url
     end
   end
end
