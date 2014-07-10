# encoding: utf-8
module SsoUtil

  SAML="saml"
  SAML_NAME_ID_FORMAT="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress";
  SSO_ALLOWED_IN_SECS = 1800
  SAML_CLOCK_DRIFT = 60 # No of secs the response time can be before the server time .. Keep this very low for security
  FIRST_NAME_STRS = [ "givenname" , "FirstName", "User.FirstName", "username" ].map &:to_sym  # username will always return something
  LAST_NAME_STRS = [ "surname", "LastName", "User.LastName" ].map &:to_sym 
  PHONE_NO_STRS = [ "phone"].map &:to_sym 

  class SAMLResponse

    attr_accessor :user_name, :email , :phone , :error_message

    def initialize(valid,user_name,email,phone,error_message)
      @valid = valid;
      @user_name = user_name;
      @email = email;
      @phone = phone
      @error_message = error_message ? error_message : "";
    end

    def valid?
      @valid
    end
  end

  def sso_login_page_redirect
    #redirect to SSO login page
    if current_account.is_saml_sso?
      settings = get_saml_settings(current_account)
      redirect_to OneLogin::RubySaml::Authrequest.new.create(settings)
    else
      host_url = "host_url=#{request.host}"
      sso_url = current_account.sso_login_url

      if sso_url.include? "?" 
        sso_url += "&#{host_url}"
      else
        sso_url += "?#{host_url}"
      end
      redirect_to sso_url;
    end
  end

  def get_saml_settings(acc)
    settings = OneLogin::RubySaml::Settings.new

    settings.issuer = request.host;
    port = Rails.env.development? ? ":3000" : ""
    settings.assertion_consumer_service_url = "#{request.protocol}#{request.host}#{port}/login/saml"

    settings.idp_cert_fingerprint = acc.sso_options[:saml_cert_fingerprint]
    settings.idp_sso_target_url = acc.sso_options[:saml_login_url]
    settings.name_identifier_format = SAML_NAME_ID_FORMAT ;
    settings
  end


  def handle_sso_response(user_email_id , user_name , phone )
    @current_user = current_account.all_users.find_by_email(user_email_id)

    if @current_user && @current_user.deleted?
      flash[:notice] = t(:'flash.login.deleted_user')
      redirect_to login_normal_url and return
    end

    if !@current_user
      options = {}
      options[:name] = user_name
      options[:phone] = phone unless phone.blank?

      @current_user = create_user(user_email_id,current_account,nil, options)
      @current_user.active = true
      saved = @current_user.save
    elsif current_account.sso_enabled?
      @current_user.name =  user_name
      @current_user.active = true
      saved = @current_user.save
    end

    @user_session = @current_user.account.user_sessions.new(@current_user)
    if @user_session.save
      remove_old_filters  if @current_user.agent?
      flash[:notice] = t(:'flash.login.success')
      redirect_back_or_default(params[:redirect_to] || '/')  if grant_day_pass
    else
      flash[:notice] = t(:'flash.login.failed')
      redirect_to login_normal_url
    end
  end

  def validate_saml_response(acc, saml_xml)

    user_name = user_email_id = phone = error_message = "";

    response = OneLogin::RubySaml::Response.new(saml_xml, :allowed_clock_drift => SAML_CLOCK_DRIFT)
    response.settings = get_saml_settings(acc)

    if response.is_valid?
      user_email_id = response.name_id
      user_name = response.attributes[:username] # default user name is actually just the part before @ in the email

      first_name = get_first_match(response.attributes , FIRST_NAME_STRS)
      last_name = get_first_match(response.attributes , LAST_NAME_STRS)
      phone = get_first_match(response.attributes , PHONE_NO_STRS)

      user_name = first_name if first_name;
      user_name += " " + last_name if last_name;
    else
      begin
        Rails.logger.debug("Got an invalid response from SAML Provider #{response.document}")
        response.validate! # force validation to get exact error
        error_message = "Login Rejected"
      rescue Exception => e
        Rails.logger.error("SAML Validation Error : #{e.message}");
        error_message = " Validation Failed :  #{e.message}"
      end
    end
    SAMLResponse.new(response.is_valid? , user_name , user_email_id, phone, error_message);
  end

  private
    def get_first_match(attributes , keys)
      keys.each do |key|
        return attributes[key] if attributes[key]
      end
      return nil #not found
    end

end
