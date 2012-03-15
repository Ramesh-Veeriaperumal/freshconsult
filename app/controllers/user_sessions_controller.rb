require "digest"
class UserSessionsController < ApplicationController
  
require 'gapps_openid'
require 'rack/openid'
require 'uri'
require 'openid'
require 'oauth/consumer' 
require 'oauth/request_proxy/action_controller_request'
require 'oauth/signature/rsa/sha1'
require 'openssl'
  
  skip_before_filter :require_user, :except => :destroy
  skip_before_filter :check_account_state
  before_filter :check_sso_params, :only => :sso_login
  skip_before_filter :check_day_pass_usage
  
  def new
    if current_account.sso_enabled? and (request.request_uri != "/login/normal")
      redirect_to  current_account.sso_options[:login_url]
    end
    
    @user_session = current_account.user_sessions.new
  end
 
  def sso_login
    if params[:hash] == gen_hash_from_params_hash
      @current_user = current_account.users.find_by_email(params[:email])  
      unless @current_user
        @current_user = create_user(params[:email],current_account,nil,{:name => params[:name]})
        @current_user.active = true
        saved = @current_user.save
      else
        @current_user.update_attributes(:name => params[:name])
      end
      
      @user_session = @current_user.account.user_sessions.new(@current_user)
      if @user_session.save
        flash[:notice] = t(:'flash.login.success')
        redirect_back_or_default('/')  if grant_day_pass  
      else
        flash[:notice] = "Login was unscucessfull!"
        redirect_to login_normal_url
      end
    else
      redirect_to login_normal_url
    end  
  end

  def opensocial_google
    begin
      cert_file  = "#{RAILS_ROOT}/config/cert/#{params['xoauth_public_key']}"
      cert = OpenSSL::X509::Certificate.new( File.read(cert_file) )
      public_key = OpenSSL::PKey::RSA.new(cert.public_key)
      container = params['opensocial_container']
      consumer = OAuth::Consumer.new(container, public_key)
      req = OAuth::RequestProxy::ActionControllerRequest.new(request)
      sign = OAuth::Signature::RSA::SHA1.new(req, {:consumer => consumer})
      verified = sign.verify
      puts "verified = #{verified}"
      if verified
        current_account = Account.find(:first,:conditions=>{:google_domain=>params[:domain]},:order=>"updated_at DESC") unless params[:domain].blank?
        google_viewer_id = params['opensocial_viewer_id']
        google_viewer_id = params['opensocial_owner_id'] if google_viewer_id.blank?
        if google_viewer_id.blank?
          json = {:verified => :false, :reason=>t("flash.gmail_gadgets.viewer_id_not_sent_by_gmail")}
        else
          agent = Agent.find_by_google_viewer_id(google_viewer_id)
          if agent.blank?
            json = {:user_exists => :false, :t=>generate_random_hash(google_viewer_id, current_account)}  
          elsif agent.user.deleted? or !agent.user.active?
            json = {:verified => :false, :reason=>t("flash.gmail_gadgets.agent_not_active")}
          else
            json = {:user_exists => :true, :t=>agent.user.single_access_token, 
                    :url_root=>agent.user.account.full_domain, :ssl_enabled=>agent.user.account.ssl_enabled}
          end
        end
      else
        json = {:verified => :false, :reason=>t("flash.gmail_gadgets.gmail_request_unverified")}
      end
    rescue
      json = {:verified => :false, :reason=>t("flash.gmail_gadgets.unknown_error")}
    end
    puts "result json #{json.inspect}"
    render :json => json
  end

  def generate_random_hash(google_viewer_id, account)
     generated_hash = Digest::MD5.hexdigest(DateTime.now.to_s + google_viewer_id)
     KeyValuePair.delete_all(["value=? and obj_type=? and account_id=?", google_viewer_id, TOKEN_TYPE, account])
     kvp = KeyValuePair.new({:key=>generated_hash, :value=>google_viewer_id, :obj_type=>TOKEN_TYPE, :account_id=>account})
     kvp.save! # if it throws exception, let it propagate. Without storing this info anyway we cannot proceed. 
     return generated_hash;
  end

  def gen_hash_from_params_hash
    Digest::MD5.hexdigest(params[:name]+params[:email]+current_account.shared_secret)
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
      
      redirect_back_or_default('/') if grant_day_pass
      #Unable to put 'grant_day_pass' in after_filter due to double render
    else
      note_failed_login
      render :action => :new
    end
  end
  
  def destroy
    current_user_session.destroy unless current_user_session.nil? 
    if current_account.sso_enabled? and !current_account.sso_options[:logout_url].blank?
      return redirect_to current_account.sso_options[:logout_url]
    end
    
    redirect_to root_url
  end
  
  def signup_complete
    @current_user = current_account.users.find_by_perishable_token(params[:token]) 
    if @current_user.nil?
      flash[:notice] = "Please provide valid login details!!"
      return redirect_to login_url 
    end
    
    @user_session = current_account.user_sessions.new(@current_user)
    if @user_session.save
      @current_user.deliver_account_admin_activation
      SubscriptionNotifier.send_later(:deliver_welcome, current_account)
      flash[:notice] = t('signup_complete_activate_info')
      redirect_to admin_getting_started_index_path  
    else
      flash[:notice] = "Please provide valid login details!"
      render :action => :new
    end
  end

  def openid_google
    base_domain = AppConfig['base_domain'][RAILS_ENV]
    domain_name = params[:domain] 
    signup_url = "https://signup."+base_domain+"/account/signup_google?domain="+domain_name unless domain_name.blank?   
    #signup_url = "http://localhost:3000/account/signup_google?domain="+domain_name unless domain_name.blank?
    @current_account = Account.find(:first,:conditions=>{:google_domain=>domain_name},:order=>"updated_at DESC")
    full_domain  = "#{domain_name.split('.').first}.#{AppConfig['base_domain'][RAILS_ENV]}" unless domain_name.blank?
    @current_account = Account.find_by_full_domain(full_domain) if @current_account.blank?
    cust_url = @current_account.full_domain unless @current_account.blank?   
    if @current_account.blank?      
      flash[:notice] = "There is no account associated with your domain. You may signup here"
      redirect_to signup_url and return unless signup_url.blank? 
      raise ActiveResource::ResourceNotFound
    end
    ##Need to handle the case where google is integrated with a seperate domain-- 2 times we need to authenticate
    t_url = params[:t] ? "&t="+params[:t] : "" # passed token will be preserved for authentication. 
    return_url = "http://"+cust_url+"/authdone/google?domain="+params[:domain]+t_url
    logger.debug "the return_url is :: #{return_url}"    
    re_alm = "http://"+cust_url    
    logger.debug "domain name is :: #{domain_name}"
    url = nil    
    url = ("https://www.google.com/accounts/o8/site-xrds?hd=" + params[:domain]) unless domain_name.blank?
    authenticate_with_open_id(url,{ :required => ["http://axschema.org/contact/email", :email] , :return_to => return_url, :trust_root =>re_alm}) do |result, identity_url, registration| end
  end

  def google_auth_completed    
    resp = request.env[Rack::OpenID::RESPONSE]  
    email = nil
    flash = {}
    if resp.status == :success
      email = get_email resp
      provider = 'open_id' 
      identity_url = resp.display_identifier
      logger.debug "The display identifier is :: #{identity_url.inspect}"
      @auth = Authorization.find_by_provider_and_uid_and_account_id(provider, identity_url,current_account.id)
      @current_user = @auth.user unless @auth.blank?
      @current_user = current_account.all_users.find_by_email(email) if @current_user.blank?
      gmail_gadget_temp_token = params[:t]
      unless gmail_gadget_temp_token.blank?
        kvp = KeyValuePair.find_by_key(gmail_gadget_temp_token)
        @gauth_error=true
        if kvp.blank? or kvp.value.blank?
          @notice = t(:'flash.gmail_gadgets.kvp_missing')
        elsif @current_user.blank?
          @notice = t(:'flash.gmail_gadgets.user_missing')
        elsif @current_user.agent.blank?
          @notice = t(:'flash.gmail_gadgets.agent_missing')
        else
          google_viewer_id = kvp.value
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
          if gmail_gadget_temp_token.blank?
            flash[:notice] = t(:'flash.g_app.authentication_success')
            redirect_back_or_default('/')
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
    elsif !gmail_gadget_temp_token.blank?
      @notice = t(:'flash.g_app.authentication_failed')
      render :action => 'gmail_gadget_auth', :layout => 'layouts/widgets/contacts.widget'
    end
  end

  private
    def check_sso_params
      if params[:name].blank? or params[:email].blank? or params[:hash].blank?
        flash[:notice] = t(:'flash.login.sso.expected_params')
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
      end
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
      @contact.email = email
      @contact.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
      return @contact
    end
    TOKEN_TYPE = "OpenSocialFirstTimeAccessToken"  
end
