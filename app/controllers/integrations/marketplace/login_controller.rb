class Integrations::Marketplace::LoginController < ApplicationController
  include Integrations::Marketplace::LoginHelper

  layout :choose_layout

  skip_before_filter :check_privilege, :only => [:login]

  before_filter :get_user_from_redis, :only => [:login]

  def login
    if @login_user.nil? || @login_user.deleted
      user_deleted
    else
      create_user_session(@login_user)
    end
  end

  protected

  def choose_layout
    'signup_google'
  end

  private

  def initialize_attr(data)
    if (data['email_not_reqd'] && data['remote_id']) || (data['email'] && data['remote_id'])
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
    else
      @email = nil
      @remote_id = nil
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
          redirect_url = send(@app_name + '_url')
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
    redis_oauth_key = params['app_name'] + "_SSO:" + params['remote_id']
    email = get_others_redis_key(redis_oauth_key)
    @login_user = get_user(current_account, email)
    remove_others_redis_key(redis_oauth_key)
  end
end
