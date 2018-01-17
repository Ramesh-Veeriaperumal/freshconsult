module AuthenticationSystem
  
  def self.included(base)
    base.helper_method :current_user_session, :current_user, :logged_in?, :revert_current_user, :is_assumed_user?, :is_allowed_to_assume?
  end
  
  #### Need to remove this method - kiran
  def update_last_seen_at
  end

  def login_required
      if !current_user
        return false
      end
  end


  private

    def is_assumed_user?
      session.has_key?(:assumed_user)
    end
  
    def is_allowed_to_assume?(user)
      return false if 
        is_assumed_user? or !current_user.can_assume?(user) 
      return false unless current_account.assume_identity_enabled?
      privilege?(:manage_users)
    end

    def assume_identity_for_user(user)
      if is_allowed_to_assume?(user)
        session[:original_user] = current_user.id
        session[:assumed_user] = user.id
        true
      else
        false
      end
    end
    
    def delete_assume_user_keys
      session.delete :assumed_user if session.has_key?(:assumed_user)
      session.delete :original_user if session.has_key?(:original_user)
    end

    def allowed_to_assume_with_api?(user)
      return false if !user.api_assumable?
      privilege?(:manage_users)
    end

    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      return if api_request? && current_account.freshid_enabled? && (freshid_authorized? == false)
      if is_native_mobile?
        handle_mobile_authentication(request,params)
      else
        assume_agent_email = handle_api_key(request, params)
      end
      @current_user_session = current_account.user_sessions.find
      handle_assume_identity_for_api(assume_agent_email) unless assume_agent_email.blank?
      @current_user_session
    end

    def handle_mobile_authentication(request,params)
      user_credentials = decode_auth_credentials
      if user_credentials.present?
        token = user_credentials[0] 
        payload = token.split(".")[1] 
        if payload.nil?
          params['k'] = token
          return 
        end
        user = fetch_mobile_user(Base64.decode64(payload))
        secret = user.mobile_jwt_secret if !user.nil? && !user.password_expired?
        begin
          decoded_token = decode_mobile_auth_token(token, secret.to_s) 
        rescue JWT::DecodeError
          Rails.logger.error "Invalid Mobile JWT Token"
        else 
          params['k'] = user.single_access_token          
        end
      end
    end

    def fetch_mobile_user(payload)
      payload = JSON.parse(payload, symbolize_names: true)
      if valid_payload?(payload)
        case payload[:type]
        when "email"
          current_account.user_emails.user_for_email(payload[:id])
        # Note :: Mobile app supports email only for now.
        # when "twitter" 
        #   current_account.all_users.find_by_twitter_id(payload[:id])
        # when "facebook"
        #   current_account.all_users.find_by_fb_profile_id(payload[:id])
        # when "phone"
        #   current_account.all_users.find_by_phone(payload[:id]) || current_account.all_users.find_by_mobile(payload[:id])
        else
          Rails.logger.error "Mobile Auth :: Unsupported Login Type :: #{payload[:type]}"
        end
      end
    end

    def valid_payload?(payload)
      payload.key?(:type) && payload.key?(:id)
    end
    
    def handle_api_key(request, params)
      if params['k'].blank?
        if api_request?
          # Handling the api key authentication.
          api_key_split = decode_auth_credentials
          if api_key_split.present?
            params['k'] = api_key_split[0]
            log_authentication_type(params['k'], params['format']) unless params['k'].blank?
            # Assume identity
            if api_key_split.size > 1
              matched = /assume=(.*)/.match(api_key_split[1])
              if !matched.blank? and matched.size > 1
                return matched[1]
              end
            end
          end
        end
      elsif params['format'] != "widget"
        params['k'] = nil
        Rails.logger.error "Single access token based auth requested for non widget based page.  Removing single access token."
      end
    end

    def api_request?
      SUPPORTED_API_KEY_FORMATS.include?(params['format'])
    end

    def freshid_authorized?
      api_key_split = decode_auth_credentials
      return if api_key_split.nil?
      return true if !api_key_split[0].include?('@') # Return if API Key auth
      user = current_account.users.find_by_email(api_key_split[0])
      return user.valid_freshid_password?(api_key_split[1]) if user.present?
    end

    def decode_auth_credentials
      http_auth_header = request.headers['HTTP_AUTHORIZATION']
      basic_auth_match = http_auth_header.present? ? /Basic (.*)/.match(http_auth_header) : nil
      return nil if basic_auth_match.blank? || basic_auth_match.length <= 1
      api_key_with_x = Base64.decode64(basic_auth_match[1])
      return api_key_with_x.split(":")
    end

    def handle_assume_identity_for_api(assume_agent_email)
      if api_request?
        error_code = "unauthorized"
        unless @current_user_session.blank?
          assume_agent = current_account.user_emails.user_for_email(assume_agent_email)
          puts "assume_agent : #{assume_agent.inspect}"
          if assume_agent.blank?
            error_code = "assuming_identity_user_does_not_exist"
          elsif allowed_to_assume_with_api?(assume_agent)
            session[:assumed_user] = assume_agent.id
            return true
          else
            error_code = "assuming_identity_not_allowed"
          end
        end
        @current_user_session = nil
        error_msg = {:status=>:error, :error_code=>error_code, :message=>I18n.t("#{error_code}_msg")}
        respond_to do |format|
          format.xml { render :xml => error_msg.to_xml(:root=>"result"), :status => :unauthorized }
          format.json { render :json => error_msg.to_json, :status => :unauthorized }
        end
        return false
      end
    end

    def log_out!
      current_user_session.destroy if current_user_session 
      @current_user = nil
      @current_user_session = nil
    end
  
    def current_user
      return @current_user if defined?(@current_user)

      if current_user_session
        @current_user = (session.has_key?(:assumed_user)) ? (current_account.users.find session[:assumed_user]) : current_user_session.record
      end
    end

    def revert_current_user
      @current_user = current_account.users.find session[:original_user] if session.has_key?(:original_user)
    end
  
    def require_user

      unless authorized?
        respond_to do |wants|
          wants.html do
            store_location
            flash[:notice] = password_expired? ? I18n.t(:'flash.general.password_expired') :I18n.t(:'flash.general.need_login')
            redirect_to login_url
          end
          
          wants.json do
            render :json => { :error => 'Login required' }, :status => :unauthorized
          end
        end
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = I18n.t(:'flash.general.login_not_needed')
        redirect_to root_url
        return false
      end
    end
  
    def store_location
      session[:return_to] = request.original_fullpath
    end
  
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    def freshid_auth_failure_redirect_back(flash_message_key=nil, default = '/')
      redirect_path = session.delete(:freshid_auth_failure_return_to)
      session[:flash_message] = I18n.t(flash_message_key) if flash_message_key.present?
      redirect_to(redirect_path || default)
    end

    def authenticate_admin
      authenticate_or_request_with_http_basic do |user, password|
        password_hash = Digest::MD5.hexdigest(password)
        user == 'super' && password_hash == "e621cfc8e4ee61466898a0b65279b111"
      end
    end

    def logged_in?
      current_user
    end

    def authorized?
      current_user
    end
    
    def check_day_pass_usage
      return unless qualify_for_day_pass?
      
      unless current_user.day_pass_granted_on
        store_location
        log_out!
        respond_to do |format|
          format.json { day_pass_expired_json } # defined in application_concern.
          format.all do 
            flash[:notice] = I18n.t('agent.day_pass_expired')
            redirect_to login_url
          end
        end
      end
    end
    
    def grant_day_pass(dont_redirect = false) #Need to refactor this code..
      if (qualify_for_day_pass? && !current_user.day_pass_granted_on)
        unless current_account.day_pass_config.grant_day_pass(current_user, params)
          log_out!
          flash[:notice] = I18n.t('agent.insufficient_day_pass')
          redirect_to login_url unless dont_redirect
          return nil
        end
      end
      
      true
    end
    
    # Check qualify_for_day_pass? method in api_applciation_controller if this method is modified.
    def qualify_for_day_pass?
      current_user && current_user.occasional_agent? && !current_account.subscription.trial? && !is_assumed_user?
    end

    #Differentiate API Key and Email Authentication
    def log_authentication_type(auth_token, format)
      auth_type = auth_token.include?('@') ? "UN_PASS" : "API_KEY"
      Rails.logger.info "FRESHID API V1 auth_type :: #{auth_type}, format :: #{format}, a=#{current_account.id}"
    end

    SUPPORTED_API_KEY_FORMATS = ['xml', 'json', 'widget']
end
