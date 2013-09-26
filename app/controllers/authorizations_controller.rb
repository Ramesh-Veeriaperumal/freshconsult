# encoding: utf-8
require 'httparty'
require 'cgi'
require 'json'

class AuthorizationsController < ApplicationController
  include Integrations::GoogleContactsUtil
  include Integrations::OauthHelper
  include HTTParty

  skip_before_filter :check_privilege
  before_filter :require_user, :only => [:destroy]
  before_filter :load_oauth_info, :only => [:create, :failure]
  before_filter :switch_shard
  before_filter :load_authorization, :only => [:create]

  def create
    Rails.logger.debug "@omniauth "+@omniauth.inspect
    failure if @omniauth.blank?
    @omniauth_origin = session["omniauth.origin"]
    if @omniauth['provider'] == :open_id
      @current_user = current_account.all_users.find_by_email(@omniauth['info']['email'])  unless  current_account.blank?
      create_for_sso(@omniauth)
    elsif @omniauth['provider'] == "twitter"
      twitter_id = @omniauth['info']['nickname']
      @current_user = current_account.all_users.find_by_twitter_id(twitter_id)  unless  current_account.blank?
      create_for_sso(@omniauth)
    elsif @omniauth['provider'] == "facebook"
      create_for_facebook(params)
    elsif @omniauth['provider'] == "google"
      create_for_google(params)
    elsif OAUTH2_PROVIDERS.include?(@omniauth['provider'])
      create_for_oauth2(@omniauth['provider'], params)
    elsif EMAIL_MARKETING_PROVIDERS.include?(@omniauth['provider'])
      create_for_email_marketing_oauth(@omniauth['provider'], params)
    end
  end

  def failure
    port = (Rails.env.development? ? ":#{request.port}" : '')
    path = ''
    if @provider 
      app = Integrations::Application.find_by_name(@provider)
      path = '/integrations/applications' if (app and !app.options[:user_specific_auth]) 
    end
    flash[:notice] = t(:'flash.g_app.authentication_failed')
    redirect_to portal_url+port+path
  end
  
  def destroy
    @authorization = current_user.authorizations.find(params[:id])
    @authorization.destroy
    redirect_to root_url
  end

  private
    def load_oauth_info
      origin = nil
      origin = request.env["omniauth.origin"] unless request.env["omniauth.origin"].blank?
      origin = params[:origin] if origin.blank?
      @omniauth = request.env['omniauth.auth'] 
      @provider = @omniauth['provider'] if @omniauth
      @provider ||= params[:provider] unless params[:provider].blank?
      Rails.logger.debug("\n\norigin: #{origin}\n@provider: #{@provider}")

      raise ActionController::RoutingError, "Not Found" if origin.blank? and origin_required?
      
      # Temporary fix for OAuth flow during deployment
      puts "origin: #{origin.inspect}"
        if origin and origin.starts_with?('a_') 
          @look_for_account = true
          origin.gsub!( /a_/i , '')
        else
          @look_for_account = false
        end
      # ends

      # In view of google_oauth2 (for multiple apps)
      if is_numeric?(origin)                  
        # debugger
        origin = origin.to_i if origin_required?
        # debugger
        @app_name = Integrations::Constants::APP_NAMES[@provider.to_sym] unless @provider.blank?
      elsif
        origin = CGI.parse(origin)
        @app_name = origin['app_name'][0].to_s
        origin = origin['pid'][0].to_i if origin.has_key?('pid')
      end

      # Temporary fix for OAuth flow during deployment
        unless origin.blank? or !is_numeric?(origin)
          Rails.logger.debug "params: #{request.env['omniauth.params'].inspect}"
          if @look_for_account
            Rails.logger.debug "::::::: ORIGIN REPRESENTS :::::      ACCOUNT_ID\n\n\n"
            @account_id = origin.to_i
          else
            Rails.logger.debug "::::::: ORIGIN REPRESENTS :::::      PORTAL_ID\n\n\n"
            portal = Portal.find(origin.to_i)
            @account_id = portal.account_id if portal
          end
        end
      #fix ends
    end

    def switch_shard
      user_account_id = origin_required? ? @account_id : current_account.id
      raise ActionController::RoutingError, "Not Found" if user_account_id.nil?
      Sharding.select_shard_of (user_account_id) do
        dummy = 0
      end
    end

    def load_authorization
      @auth = Authorization.find_from_hash(@omniauth,current_account.id) unless @provider == "facebook"
      if (@provider == :open_id or @provider == :twitter or @provider == :facebook)
        @provider = (@provider == :open_id ? :google : @provider)
        requires_feature("#{@provider}_signin")
      end
    end

    def origin_required?
      puts "request.host :::::: #{request.host}"
      puts "config_url   :::::: #{AppConfig['integrations_url'][Rails.env]}"
      request.host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '').gsub(/:3000/i, '')
    end

    def create_for_google(params)
      user_info = @omniauth['info']
      unless user_info.blank?
        if @omniauth_origin.blank? || @omniauth_origin.include?("integrations") 
          Rails.logger.error "The session variable to omniauth is not preserved or not set properly."
          @omniauth_origin = "install"
        end
        @google_account = Integrations::GoogleAccount.new
        @db_google_account = Integrations::GoogleAccount.find_by_account_id_and_email(current_account, user_info["email"])
        if !@db_google_account.blank? && @omniauth_origin == "install"
          Rails.logger.error "As already an account has been configured can not configure one more account."
          flash[:error] = t("integrations.google_contacts.already_exist")
          redirect_to edit_integrations_installed_application_path(params[:iapp_id]) 
        else
          @existing_google_accounts = Integrations::GoogleAccount.find_all_by_account_id(current_account)
          @google_account.account = current_account
          @google_account.token = @omniauth['credentials']['token']
          @google_account.secret = @omniauth['credentials']['secret']
          @google_account.name = user_info["name"]
          @google_account.email = user_info["email"]
          @google_account.sync_group_name = "Freshdesk Contacts"
          Rails.logger.debug "@google_account details #{@google_account.inspect} existing_google_accounts #{@existing_google_accounts.inspect}"
          # Fetch all the groups
          @google_groups = @google_account.fetch_all_google_groups
          # Reuse the group id, if the group with same name already exist.
          @google_groups.each { |g_group|
            @google_account.sync_group_id = g_group.group_id if g_group.name == @google_account.sync_group_name
          }
          render 'integrations/google_accounts/edit'
        end
      end
    end

    def create_for_oauth2(provider, params)
      Account.reset_current_account

      if provider  == 'surveymonkey'
        access_token = @omniauth.credentials
      else
        access_token = get_oauth2_access_token(provider, @omniauth.credentials.refresh_token, @app_name)
      end
      
      config_params = { 
        'app_name' => "#{@app_name}",
        'refresh_token' => "#{@omniauth.credentials.refresh_token}",
        'oauth_token' => "#{access_token.token}"
      }
      config_params['instance_url'] = "#{access_token.params['instance_url']}" if provider=='salesforce'
      config_params = config_params.to_json
      Rails.logger.debug "config_params: #{config_params}"
      #Redis::KeyValueStore is used to store oauth2 configurations since we redirect from login.freshdesk.com to the
      #user's account and install the application from inside the user's account.
      key_options = { :account_id => @account_id, :provider => @app_name}
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration, :expire => 300}).set_key
      port = (Rails.env.development? ? ":#{request.port}" : '')
      controller = ( Integrations::Application.find_by_name(@app_name).user_specific_auth? ? 'integrations/user_credentials' : 'integrations/applications' )
      redirect_url = portal_url + port + "/#{controller}/oauth_install/#{@app_name}"
      redirect_to redirect_url
    end

      def create_for_email_marketing_oauth(provider, params)
      config_params = {}
      Account.reset_current_account
      
      config_params["mailchimp"] = "{'app_name':'#{provider}', 'api_endpoint':'#{@omniauth.extra.metadata.api_endpoint}', 'oauth_token':'#{@omniauth.credentials.token}'}" if provider == "mailchimp"
      config_params["constantcontact"] = "{'app_name':'#{provider}', 'oauth_token':'#{@omniauth.credentials.token}', 'uid':'#{@omniauth.uid}'}" if provider == "constantcontact"
      config_params = config_params[provider].gsub("'","\"")

      #Redis::KeyValueStore is used to store salesforce/nimble configurations since we redirect from login.freshdesk.com to the 
      #user's account and install the application from inside the user's account.
      key_options = { :account_id => @account_id, :provider => provider}
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration, :expire => 300}).set_key
      port = (Rails.env.development? ? ":#{request.port}" : '')
      redirect_url = portal_url + port + "/integrations/applications/oauth_install/"+provider
       
      redirect_to redirect_url
    end

    def create_for_facebook(params)
      Account.reset_current_account
      state = "/facebook" if params[:state]
      user_account = Account.find @account_id
      user_account.make_current
      fb_email = @omniauth['info']['email']
      unless user_account.blank?
        @current_user = user_account.all_users.find_by_email(fb_email) unless fb_email.blank?
        @auth = Authorization.find_from_hash(@omniauth,user_account.id)
        fb_profile_id = @omniauth['info']['nickname']
        @current_user = user_account.all_users.find_by_fb_profile_id(fb_profile_id) if @current_user.blank?
        if create_for_sso(@omniauth, user_account)
          curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
          random_hash = Digest::MD5.hexdigest(curr_time)
          key_options = { :account_id => user_account.id, :user_id => @current_user.id, :provider => @omniauth['provider']}
          key_spec = Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
          Redis::KeyValueStore.new(key_spec, curr_time, {:group => :integration, :expire => 300}).set_key
          port = (Rails.env.development? ? ":#{request.port}" : '')
          redirect_to portal_url(user_account) + "#{port}#{state}/sso/login?provider=facebook&uid=#{@omniauth['uid']}&s=#{random_hash}" 
        end
      end
    end

    def create_session
      @user_session = @current_user.account.user_sessions.new(@current_user)
      if @user_session.save
          redirect_back_or_default('/') if grant_day_pass
      else
        flash[:notice] = t(:'flash.g_app.authentication_failed')
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
      end
    end

    def show_deleted_message
      if params[:state]
        render :text => t(:'flash.g_app.page_unavailable')
      else
        flash[:notice] = t(:'flash.g_app.page_unavailable')
        redirect_to login_url
      end
    end
    
    def make_usr_active
       @current_user.active = true 
       @current_user.save!
    end

    def create_for_sso(hash, user_account = nil)
      account = (user_account.blank?) ? current_account : user_account
      if !@current_user.blank? and !@auth.blank?
        if @current_user.deleted?
          show_deleted_message
          return false
        end
        make_usr_active
      elsif !@current_user.blank?
        @current_user.authorizations.create(:provider => hash['provider'], :uid => hash['uid'], :account_id => account.id) #Add an auth to existing user  
        make_usr_active
      else  
        @new_auth = create_from_hash(hash, account) 
        @current_user = @new_auth.user
      end
      create_session unless @omniauth['provider'] == "facebook"
      return true
    end
    
    def create_from_hash(hash, account)
      user = account.users.new  
      user.name = hash['info']['name']
      user.email = hash['info']['email']
      unless hash['info']['nickname'].blank?
        user.twitter_id = hash['info']['nickname'] if hash['provider'] == 'twitter'
        user.fb_profile_id = hash['info']['nickname'] if hash['provider'] == 'facebook'
      end
      user.helpdesk_agent = false
      user.active = true
      user.save 
      user.reset_persistence_token! 
      Authorization.create(:user_id => user.id, :uid => hash['uid'], :provider => hash['provider'],:account_id => account.id)
    end

    def portal_url account=nil
        account ||= Account.find(@account_id || DomainMapping.find_by_domain(request.host).account_id)
        portal = account.main_portal
        protocol  = portal.ssl_enabled? ? 'https://' : 'http://'
        return (protocol + portal.host)
    end

    def is_numeric? s
      !!s.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/)
    end

    OAUTH2_PROVIDERS = ["salesforce", "nimble", "google_oauth2", "surveymonkey"]
    EMAIL_MARKETING_PROVIDERS = ["mailchimp", "constantcontact"]
end
