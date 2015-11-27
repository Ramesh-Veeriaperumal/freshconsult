require "digest"
class UserSessionsController < ApplicationController

require 'gapps_openid'
require 'rack/openid'
require 'uri'
require 'openid'
require 'oauth/consumer' 
require 'oauth/request_proxy/rack_request'
require 'oauth/signature/rsa/sha1'
require 'openssl'

include Redis::RedisKeys
include Redis::TicketsRedis
include SsoUtil
include Mobile::Actions::Push_Notifier
include GoogleLoginHelper

  skip_before_filter :check_privilege, :verify_authenticity_token  
  skip_before_filter :require_user, :except => :destroy
  skip_before_filter :check_account_state
  before_filter :check_sso_params, :only => :sso_login
  skip_before_filter :check_day_pass_usage
  before_filter :set_native_mobile, :only => [:create, :destroy]
  skip_filter :select_shard, :only => [:oauth_google_gadget,:opensocial_google]
  skip_before_filter :determine_pod, :only => [:openid_google,:opensocial_google]
  skip_before_filter :set_current_account, :only => [:oauth_google_gadget,:opensocial_google] 
  skip_before_filter :set_locale, :only => [:oauth_google_gadget,:opensocial_google] 
  skip_before_filter :ensure_proper_protocol, :only => [:oauth_google_gadget,:opensocial_google] 
  
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
    if params[:hash] == gen_hash_from_params_hash
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
      elsif current_account.sso_enabled?
        @current_user.name =  params[:name]
        @current_user.phone = params[:phone] unless params[:phone].blank?
        @current_user.customer_id = current_account.customers.find_or_create_by_name(params[:company]).id unless params[:company].blank?
        @current_user.active = true
        saved = @current_user.save
      end
      
      @user_session = @current_user.account.user_sessions.new(@current_user)
      if saved && @user_session.save
        if is_native_mobile?
          cookies["mobile_access_token"] = { :value => @current_user.helpdesk_agent ? @current_user.single_access_token : 'customer', :http_only => true } 
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

  def opensocial_google
    begin
      Account.reset_current_account
      cert_file  = "#{Rails.root}/config/cert/#{params['xoauth_public_key']}"
      cert = OpenSSL::X509::Certificate.new( File.read(cert_file) )
      public_key = OpenSSL::PKey::RSA.new(cert.public_key)
      container = params['opensocial_container']
      consumer = OAuth::Consumer.new(container, public_key)
      req = OAuth::RequestProxy::RackRequest.new(request)
      sign = OAuth::Signature::RSA::SHA1.new(req, {:consumer => consumer})
      verified = sign.verify
      if verified
        account_id = find_account_by_google_domain(params[:domain])
        if account_id.blank?
          json = {:verified => :false, :reason=>t("flash.gmail_gadgets.account_not_associated")}
        else
          Sharding.select_shard_of(account_id) do
            account = Account.find(account_id)
            account.make_current
            google_viewer_id = params['opensocial_viewer_id']
            google_viewer_id = params['opensocial_owner_id'] if google_viewer_id.blank?
            if google_viewer_id.blank?
              json = {:verified => :false, :reason=>t("flash.gmail_gadgets.viewer_id_not_sent_by_gmail")}
            else
              agent = account.agents.find_by_google_viewer_id(google_viewer_id)
              if agent.blank?
                json = {:user_exists => :false, :t=>generate_random_hash(google_viewer_id, account)}  
              elsif agent.user.deleted? or !agent.user.active?
                json = {:verified => :false, :reason=>t("flash.gmail_gadgets.agent_not_active")}
              else
                json = {:user_exists => :true, :t=>agent.user.single_access_token, 
                      :url_root=>agent.user.account.full_domain, :ssl_enabled=>agent.user.account.ssl_enabled}
              end
            end
          end
        end
      else
        json = {:verified => :false, :reason=>t("flash.gmail_gadgets.gmail_request_unverified")}
      end
    rescue => e
      Rails.logger.error "Problem in processing google opensocial request. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      json = {:verified => :false, :reason=>t("flash.gmail_gadgets.unknown_error")}
    end
    Rails.logger.debug "result json #{json.inspect}"
    render :json => json
  end

  def generate_random_hash(google_viewer_id, account)
     generated_hash = Digest::MD5.hexdigest(DateTime.now.to_s + google_viewer_id)
     key_options = { :account_id => account.id, :token => generated_hash}
     key_spec = Redis::KeySpec.new(AUTH_REDIRECT_GOOGLE_OPENID, key_options)
     Redis::KeyValueStore.new(key_spec, google_viewer_id, {:group => :integration, :expire => 300}).set_key
     return generated_hash
  end

  
  
  def show
    redirect_to :action => :new
  end
  
  def create  
    @user_session = current_account.user_sessions.new(params[:user_session])
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
            else
              render :json => {:login => 'success' , :auth_token => @current_user.single_access_token}.to_json
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
          json = "{'login':'failed',"
          @user_session.errors.messages.each do |attr, error|
            error.each do |err|
              json << "'attr' : '#{attr}', 'message' : '#{err}'}"
              break # even if password & email passed here is incorrect, only email is validated first. so this array will always have one element. This break will ensure that if in case...
            end
          end
          render :json => json
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

    current_user_session.destroy unless current_user_session.nil?
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
      @current_user.deliver_admin_activation
      #SubscriptionNotifier.send_later(:deliver_welcome, current_account)
      flash[:notice] = t('signup_complete_activate_info')
      redirect_to_getting_started
    else
      flash[:notice] = "Please provide valid login details!"
      render :action => :new
    end
  end

  def oauth_google_gadget
    base_domain = AppConfig['base_domain'][Rails.env]
    domain_name = params[:domain] 
    signup_url = "https://signup."+base_domain+"/account/signup_google?domain="+domain_name unless domain_name.blank?
    account_id = find_account_by_google_domain(domain_name)
    if account_id.blank?      
      flash[:notice] = "There is no account associated with your domain. You may signup here"
      redirect_to signup_url and return unless signup_url.blank? 
      raise ActiveResource::ResourceNotFound
    end
    Sharding.select_shard_of(account_id) do
      @current_account = Account.find(account_id)
      @current_account.make_current
      @current_portal = @current_account.main_portal
      @current_portal.make_current
      cust_url = @current_account.full_domain
      gv_id = params[:t] || "" # passed token will be preserved for authentication.
      redirect_to construct_google_auth_url(cust_url, 'google_gadget_oauth2') << "%26gv_id%3D" << "#{gv_id}" # "google_gadget_oauth2" is the base key value in the oauth_config.yml file.
    end
  end
  
  def find_account_by_google_domain(google_domain_name)
    unless google_domain_name.blank?
      account_id = nil
      gm = GoogleDomain.find_by_domain(google_domain_name)
      if gm.blank?
        full_domain  = "#{google_domain_name.split('.').first}.#{AppConfig['base_domain'][Rails.env]}"
        sm = ShardMapping.fetch_by_domain(full_domain)
        account_id = sm.account_id if sm
      else
        account_id = gm.account_id
      end
      account_id
    end
  end

  def google_auth_completed    
    resp = request.env[Rack::OpenID::RESPONSE]  
    email = nil
    flash = {}
    gmail_gadget_temp_token = params[:t]
    if resp.status == :success
      email = get_email resp
      provider = 'open_id' 
      identity_url = resp.display_identifier
      logger.debug "The display identifier is :: #{identity_url.inspect}"
      @auth = Authorization.find_by_provider_and_uid_and_account_id(provider, identity_url,current_account.id)
      @current_user = @auth.user unless @auth.blank?
      @current_user = current_account.user_emails.user_for_email(email) if @current_user.blank?
      unless gmail_gadget_temp_token.blank?
        key_options = {:account_id => current_account.id, :token => gmail_gadget_temp_token}
        kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(AUTH_REDIRECT_GOOGLE_OPENID, key_options))
        kv_store.group = :integration
        google_viewer_id = kv_store.get_key
        @gauth_error=true
        if google_viewer_id.blank?
          @notice = t(:'flash.gmail_gadgets.kvp_missing')
        elsif @current_user.blank?
          @notice = t(:'flash.gmail_gadgets.user_missing')
        elsif !@current_user.agent?
          @notice = t(:'flash.gmail_gadgets.agent_missing')
        else
          @gauth_error=false
        end
      else
        if @current_user.blank?  
          @current_user = create_user(email,current_account,identity_url) 
        end
      end

      if @gauth_error
        render :action => 'gmail_gadget_auth', :layout => 'layouts/widgets/contacts.widget'
      else
        @current_user.active = true 
        saved = @current_user.save
        if @auth.blank?
          @current_user.authorizations.create(:provider => provider, :uid => identity_url, :account_id => current_account.id) #Add an auth in existing user
        end
        puts "User saved status: #{saved}"

        @user_session = current_account.user_sessions.new(@current_user)  
        if @user_session.save
          logger.debug " @user session has been saved :: #{@user_session.inspect}"
          
          remove_old_filters if @current_user.agent?

          if gmail_gadget_temp_token.blank?
            flash[:notice] = t(:'flash.g_app.authentication_success')        
            if (@current_user.first_login? && @current_user.privilege?(:manage_account))
               redirect_to admin_getting_started_index_path
            else
              redirect_back_or_default('/')            
            end  
          else
            @current_user.agent.google_viewer_id = google_viewer_id
            @current_user.agent.save!
            @notice = t(:'flash.g_app.authentication_success')
            render :action => 'gmail_gadget_auth', :layout => 'layouts/widgets/contacts.widget'
          end
        else
          flash[:notice] = t(:'flash.g_app.authentication_failed')
          redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
        end
      end
    elsif gmail_gadget_temp_token.blank?
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    else
      @notice = t(:'flash.g_app.authentication_failed')
      render :action => 'gmail_gadget_auth', :layout => 'layouts/widgets/contacts.widget'
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
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
      elsif !params[:timestamp].blank? and !params[:timestamp].to_i.between?((time_in_utc - SSO_ALLOWED_IN_SECS),( time_in_utc + SSO_CLOCK_DRIFT ))
        flash[:notice] = t(:'flash.login.sso.invalid_time_entry')
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)  
      end
    end

    def gen_hash_from_params_hash
      if params[:timestamp].blank?
        Digest::MD5.hexdigest(params[:name]+params[:email]+current_account.shared_secret)
      else
        digest  = OpenSSL::Digest.new('MD5')
        OpenSSL::HMAC.hexdigest(digest,current_account.shared_secret,params[:name]+params[:email]+params[:timestamp])
      end
    end

    def get_time_in_utc
      Time.now.getutc.to_i
    end

    def can_turn_off_round_robin?
      current_user && current_user.agent? && current_user.agent.available? && current_account.features?(:round_robin) && !current_account.features?(:disable_rr_toggle) 
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
      @contact.customer_id = current_account.customers.find_or_create_by_name(options[:company]).id unless options[:company].blank?
      @contact.email = email
      @contact.helpdesk_agent = false
      @contact.language = current_portal.language
      return @contact
    end
end
