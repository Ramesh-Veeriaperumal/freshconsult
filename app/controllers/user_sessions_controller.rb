require "digest"
class UserSessionsController < ApplicationController

require 'gapps_openid'
require 'rack/openid'
require 'uri'
require 'openid'

include Redis::RedisKeys
include Redis::TicketsRedis
include SsoUtil
include Mobile::Actions::Push_Notifier

  skip_before_filter :check_privilege, :verify_authenticity_token  
  skip_before_filter :require_user, :except => :destroy
  skip_before_filter :check_account_state
  before_filter :check_sso_params, :only => :sso_login
  skip_before_filter :check_day_pass_usage
  before_filter :set_native_mobile, :only => [:create, :destroy]
  skip_after_filter :set_last_active_time
  
  def new
    flash.keep
    # Login normal supersets all login access (can be used by agents)
    if request.path == "/login/normal"
      @user_session = current_account.user_sessions.new
    elsif current_account.sso_enabled?
      sso_login_page_redirect
    else
      #Redirect to portal login by default
      return redirect_to support_login_path
    end
  end

  # Handles response from SAML provider
  def saml_login
    saml_response = validate_saml_response(current_account, params[:SAMLResponse])
    relay_state_url = params[:RelayState]

    sso_data = {
      :name => saml_response.user_name,
      :email => saml_response.email,
      :phone => saml_response.phone,
      :company => saml_response.company
    }

    if saml_response.valid?
      handle_sso_response(sso_data, relay_state_url)
    else
      flash[:notice] = t(:'flash.login.failed') + " -  #{saml_response.error_message}"
      redirect_to login_normal_url
    end
  end

  def sso_login
    if sso_hash_validated?
      @current_user = current_account.user_emails.user_for_email(params[:email])  
      
      if @current_user && @current_user.deleted?
        flash[:notice] = t(:'flash.login.deleted_user')
        redirect_to login_normal_url and return
      end
      
      if !@current_user
        sso_user_options = {:name => params[:name]}
        sso_user_options[:phone] = params[:phone] unless params[:phone].blank?
        sso_user_options[:company] = params[:company] unless params[:company].blank?
        @current_user = create_user(params[:email],current_account,nil,sso_user_options)
        @current_user.active = true
        saved = @current_user.save
      else
        @current_user.name =  params[:name]
        @current_user.phone = params[:phone] unless params[:phone].blank?
        @current_user.company_name = params[:company] if params[:company].present?
        @current_user.active = true
        saved = @current_user.save
      end
      
      @user_session = @current_user.account.user_sessions.new(@current_user)
      @user_session.web_session = true unless is_native_mobile?
      if saved && @user_session.save
        if is_native_mobile?
          cookies["mobile_access_token"] = { :value => @current_user.mobile_auth_token, :http_only => true } 
          cookies["fd_mobile_email"] = { :value => @current_user.email, :http_only => true } 
        end
        flash.discard
        remove_old_filters  if @current_user.agent?
        redirect_back_or_default(params[:redirect_to] || '/')  if grant_day_pass  
      else
        cookies["mobile_access_token"] = { :value => 'failed', :http_only => true } if is_native_mobile?
        flash[:notice] = t(:'flash.login.failed')
        redirect_to login_normal_url
      end
    else
      cookies["mobile_access_token"] = { :value => 'failed', :http_only => true } if is_native_mobile?
      flash[:notice] = t(:'flash.login.failed')
      redirect_to login_normal_url
    end  
  end

  def show
    redirect_to :action => :new
  end
  
  def create  
    @user_session = current_account.user_sessions.new(params[:user_session])
    @user_session.web_session = true unless is_native_mobile?
    if @user_session.save
      #Temporary hack due to current_user not returning proper value
      @current_user_session = @user_session
      @current_user = @user_session.record
      #Hack ends here      
      if grant_day_pass 
        respond_to do |format|
          format.html {
            remove_old_filters if @current_user.agent? # Temporary
            redirect_back_or_default('/')
          }
          format.nmobile {
            if @current_user.customer? 
              @current_user_session.destroy 
              render :json => {:login => 'customer'}.to_json
            elsif @current_user.password_expired?
              render :json => {login: 'failed', attr: 'base', message: 'The email and password you entered does not match'}
            else
              render :json => {:login => 'success' , :auth_token => @current_user.mobile_auth_token }.to_json
            end
          }
        end
      end
      #Unable to put 'grant_day_pass' in after_filter due to double render
    else
      note_failed_login
      respond_to do |format|
        # format.mobile{
        #   flash[:error] = I18n.t("mobile.home.sign_in_error")
        #   redirect_to root_url
        # }
        format.html{
          redirect_to support_login_path
        }
        format.nmobile{# TODO-RAILS3
          err_resp = {login: "failed"}
          @user_session.errors.messages.each do |attribute, error|
            error.each do |err|
              err_resp.merge!(:attr => "#{attribute}", message: "#{err}")
              break # even if password & email passed here is incorrect, only email is validated first. so this array will always have one element. This break will ensure that if in case...
            end
          end
          render :json => err_resp
        } 
      end
      
    end
  end
  
  def destroy
    remove_old_filters if current_user && current_user.agent?

    mark_agent_unavailable if can_turn_off_round_robin?

    session.delete :assumed_user if session.has_key?(:assumed_user)
    session.delete :original_user if session.has_key?(:original_user)

    flash.clear if mobile?
   remove_logged_out_user_mobile_registrations if is_native_mobile?

    if current_user_session
      current_user_session.web_session = true unless is_native_mobile?
      current_user_session.destroy
    end

    if current_account.sso_enabled? and current_account.sso_logout_url.present? and !is_native_mobile?
      sso_redirect_url = generate_sso_url(current_account.sso_logout_url)
      redirect_to sso_redirect_url and return
    end
    
    respond_to do |format|
        format.html  {
          redirect_to root_url
        }
        format.nmobile{
          render :json => {:logout => 'success'}.to_json
        }
      end
  end
  
  def signup_complete
    @current_user = current_account.users.find_by_perishable_token(params[:token]) 
    if @current_user.nil?
      flash[:notice] = "Please provide valid login details!!"
      return redirect_to login_url 
    end
    
    @user_session = current_account.user_sessions.new(@current_user)
    if @user_session.save
      @current_user.reset_perishable_token!
      @current_user.deliver_admin_activation
      #SubscriptionNotifier.send_later(:deliver_welcome, current_account)
      flash[:notice] = t('signup_complete_activate_info')
      redirect_to_getting_started
    else
      flash[:notice] = "Please provide valid login details!"
      render :action => :new
    end
  end

  # ITIL Related Methods starts here

  def redirect_to_getting_started
    redirect_to admin_getting_started_index_path  
  end

  # ITIL Related Methods ends here

  private

    def remove_old_filters
      remove_tickets_redis_key(HELPDESK_TICKET_FILTERS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]})
      remove_tickets_redis_key(EXPORT_TICKET_FIELDS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]})
    end

    def mark_agent_unavailable
      Rails.logger.debug "Round Robin ==> Account ID:: #{current_account.id}, Agent:: #{current_user.email}, Value:: false, Time:: #{Time.zone.now} "
      current_user.agent.update_attribute(:available,false)
    end

    def check_sso_params
      time_in_utc = get_time_in_utc
      if ![:name, :email, :hash].all? {|key| params[key].present?}
        flash[:notice] = t(:'flash.login.sso.expected_params')
        redirect_to login_normal_url
      elsif !params[:timestamp].blank? and !params[:timestamp].to_i.between?((time_in_utc - SSO_ALLOWED_IN_SECS),( time_in_utc + SSO_CLOCK_DRIFT ))
        flash[:notice] = t(:'flash.login.sso.invalid_time_entry')
        redirect_to login_normal_url
      end
    end

    def sso_hash_validated?
      if !current_account.launched?(:enable_old_sso)
        params[:hash] == new_sso_hash
      else
        (params[:hash] == old_sso_hash) ? true : (params[:hash] == new_sso_hash)
      end
    end

    def new_sso_hash
      key = "#{params[:name]}#{current_account.shared_secret}#{params[:email]}#{params[:timestamp]}"
      params[:timestamp].blank? ? md5_digest_hash(key) : hmac_digest_hash(key)
    end

    def old_sso_hash
      Rails.logger.info  "::::: Account using old sso ::::::"
      if params[:timestamp].blank?
        Rails.logger.info  "::::: Using old sso hash without timestamp ::::::"
        md5_digest_hash(params[:name]+params[:email]+current_account.shared_secret)
      else
        hmac_digest_hash(params[:name]+params[:email]+params[:timestamp])
      end
    end

    def md5_digest_hash(key)
      Digest::MD5.hexdigest(key)
    end

    def hmac_digest_hash(key)
      digest  = OpenSSL::Digest.new('MD5')
      OpenSSL::HMAC.hexdigest(digest,current_account.shared_secret,key)
    end

    def get_time_in_utc
      Time.now.getutc.to_i
    end

    def can_turn_off_round_robin?
      current_user && current_user.agent? && 
      current_user.agent.available? && current_user.agent.toggle_availability?
    end
    
    def note_failed_login
      #flash[:error] = "Couldn't log you in as '#{params[:user_session][:email]}'"
      logger.warn "Failed login for '#{params[:user_session][:email]}' from #{request.remote_ip} at #{Time.now.utc}"
    end
  
    def get_email(resp)
      if resp.status == :success
        session[:openid] = resp.display_identifier
        logger.debug "display_identifier is ::: #{resp.display_identifier}"
        ax_response = OpenID::AX::FetchResponse.from_success_response(resp)
        email = ax_response.data["http://axschema.org/contact/email"].first  
      else
        logger.debug "Error in get_email of UserSessionsController : #{resp.status}"   
      end
    end

    def create_user(email, account,identity_url=nil,options={})
      @contact = account.users.new
      @contact.name = options[:name] unless options[:name].blank?
      @contact.phone = options[:phone] unless options[:phone].blank?
      @contact.company_name = options[:company] if options[:company].present?
      @contact.email = email
      @contact.helpdesk_agent = false
      @contact.language = current_portal.language
      return @contact
    end
end
