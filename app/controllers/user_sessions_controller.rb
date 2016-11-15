require "digest"
class UserSessionsController < ApplicationController

require 'gapps_openid'
require 'rack/openid'
require 'uri'
require 'openid'

include Redis::RedisKeys
include Redis::TicketsRedis
include Redis::OthersRedis
include SsoUtil
include Mobile::Actions::Push_Notifier

  skip_before_filter :check_privilege, :verify_authenticity_token  
  skip_before_filter :require_user, :except => :destroy
  skip_before_filter :check_account_state
  before_filter :check_sso_params, :only => :sso_login
  skip_before_filter :check_day_pass_usage
  before_filter :set_native_mobile, :only => [:create, :destroy]
  skip_after_filter :set_last_active_time
  before_filter :decode_jwt_payload, :check_jwt_required_fields, :only => [:jwt_sso_login]

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
      :company => saml_response.company,
      :title => saml_response.title,
      :external_id => saml_response.external_id
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
        @current_user.assign_company(params[:company]) if params[:company].present?
        @current_user.active = true
        saved = @current_user.save
      end
      
      @current_user_session = @current_user.account.user_sessions.new(@current_user)
      @current_user_session.web_session = true unless is_native_mobile?
      if saved && @current_user_session.save
        if is_native_mobile?
          cookies["mobile_access_token"] = { :value => @current_user.mobile_auth_token, :http_only => true } 
          cookies["fd_mobile_email"] = { :value => @current_user.email, :http_only => true } 
        end
        flash.discard
        remove_old_filters  if @current_user.agent?
        if grant_day_pass(true)
          redirect_back_or_default(params[:redirect_to] || '/')
        else
          redirect_to login_normal_url
        end
      else
        Rails.logger.debug "User save status #{@current_user.errors.inspect}"
        Rails.logger.debug "User session save status #{@current_user_session.errors.inspect}"
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

  def jwt_sso_login
    begin
      user = @decoded_payload["user"]
      phone_unique_flag = @decoded_payload["phone_unique"]
      user_overwrite = @decoded_payload["overwrite_user_fields"]
      user_companies_overwrite = @decoded_payload["overwrite_user_companies"]
      user_custom_fields = user.delete("custom_fields")
      user_companies = user.delete("user_companies")
      
      @current_user = current_account.all_users.where(:unique_external_id => user["unique_external_id"]).first if user["unique_external_id"].present?
      @current_user = current_account.user_emails.user_for_email(user["email"])  if( !@current_user && user["email"].present? )
      @current_user = current_account.all_users.where(:phone => user["phone"]).first if( !@current_user && phone_unique_flag && user["phone"].present? )
      
      if @current_user && (@current_user.deleted? || @current_user.blocked?)
        flash[:notice] = t(:'flash.login.blocked_user') if @current_user.blocked?
        flash[:notice] = t(:'flash.login.deleted_user') if @current_user.deleted?
        redirect_to login_normal_url and return
      end

      @current_user = current_account.users.new unless @current_user
      saved = update_user_for_jwt_sso(current_account, @current_user, user, user_custom_fields || {}, @current_user.new_record? || user_overwrite)

      if saved && user_companies.present? && current_account.features?(:multiple_user_companies)
        saved = set_user_companies_for_jwt_sso(current_account, @current_user, user_companies, user_companies_overwrite)
      end
      
      @current_user_session = current_account.user_sessions.new(@current_user)
      @current_user_session.web_session = true unless is_native_mobile?
      if saved && @current_user_session.save
        if is_native_mobile?
          cookies["mobile_access_token"] = { :value => @current_user.mobile_auth_token, :http_only => true } 
          cookies["fd_mobile_email"] = { :value => @current_user.email, :http_only => true } 
        end
        flash.discard
        remove_old_filters  if @current_user.agent?
        if grant_day_pass(true)
          redirect_back_or_default(params[:redirect_to] || '/')
        else
          Rails.logger
          redirect_to login_normal_url
        end 
      else
        Rails.logger.debug "User save status #{@current_user.errors.inspect}"
        Rails.logger.debug "User session save status #{@current_user_session.errors.inspect}"
        cookies["mobile_access_token"] = { :value => 'failed', :http_only => true } if is_native_mobile?
        flash[:notice] = t(:'flash.login.failed')
        redirect_to login_normal_url
      end

    rescue SsoFieldValidationError => e
      Rails.logger.debug "Field validation Error"
      flash[:notice] = t(:'flash.login.jwt_sso.wrong_param_type')
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
        flash[:notice] = t(:'flash.login.jwt_sso.expected_params')
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
      @contact.unique_external_id = options[:external_id] if options[:external_id].present?
      @contact.job_title = options[:title] if options[:title].present?
      @contact.email = email
      @contact.helpdesk_agent = false
      @contact.language = current_portal.language
      return @contact
    end

    def decode_jwt_payload
      begin
        hmac_secret = current_account.shared_secret
        token = params[:jwt_token]
        @decoded_payload = (JWT.decode token, hmac_secret, true, { :leeway => SSO_CLOCK_DRIFT, :verify_iat => true, :algorithm => 'HS512', :verify_jti => ->(jti) { validate_jti(jti) } })[0]
        exp = @decoded_payload["exp"] #expire at time
        iat = @decoded_payload["iat"] #issued at time
        if exp.blank? || iat.blank?
          flash[:notice] = t(:'flash.login.jwt_sso.expected_time_params')
          redirect_to login_normal_url and return
        end
        if (exp - iat > SSO_MAX_EXPIRE_TIME)
          flash[:notice] = t(:'flash.login.jwt_sso.exceeded_max_expire_time')
          redirect_to login_normal_url
        end
      rescue JWT::DecodeError => jwt_error
        Rails.logger.error "Error in validating paykiad : #{jwt_error.inspect} #{jwt_error.backtrace.join("\n\t")}"
        flash[:notice] = jwt_error.message
        redirect_to login_normal_url
      rescue Exception => e
        Rails.logger.error "Error in validating paykiad2 : #{e.inspect} #{e.backtrace.join("\n\t")}"
        flash[:notice] = t(:'flash.login.failed')
        redirect_to login_normal_url
      end
    end

    def check_jwt_required_fields
      user = @decoded_payload["user"]
      unless user["name"].present? && (user["unique_external_id"].present? || user["email"].present?)
        flash[:notice] = t(:'flash.login.jwt_sso.expected_user_params')
        redirect_to login_normal_url
      end
    end

    def validate_jti(jti)
      key = JWT_SSO_JTI % { :account_id => current_account.id, :jti => jti }
      val = get_others_redis_key key
      if val.nil?
        set_others_redis_with_expiry(key, 1, {:ex => SSO_MAX_EXPIRE_TIME})
        return true
      else
        return false
      end
    end

end
