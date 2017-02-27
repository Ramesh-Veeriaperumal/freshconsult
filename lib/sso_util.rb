# encoding: utf-8
module SsoUtil

  SAML="saml"
  SAML_NAME_ID_FORMAT="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  SAML_NAME_ID_UNSPECIFIED = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
  SSO_ALLOWED_IN_SECS = 1800
  SSO_CLOCK_DRIFT = 60 # No of secs the response time can be before the server time .. Keep this very low for security
  FIRST_NAME_STRS = ["givenname" , "FirstName", "User.FirstName", "username" ,
    "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"].map &:to_sym
  LAST_NAME_STRS = ["surname", "LastName", "User.LastName",
    "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"].map &:to_sym
  PHONE_NO_STRS = [:phone]
  COMPANY_NAME_STRS = [:organization, :company]
  TITLE_STRS = [:title, :job_title]
  EXTERNAL_ID_STRS = [:unique_id]
  ALLOWED_USER_DEFAULT_FIELDS = ["name", "unique_external_id", "email", "company_name", "job_title", "time_zone", "language", "mobile", "phone"].freeze
  SSO_USER_CUSTOM_FIELD_MAPPING = {
    :number => Fixnum,
    :url => String,
    :date => Date,
    :phone_number => String,
    :checkbox => "Boolean",
    :paragraph => String,
    :text => String
  }

  SSO_MAX_EXPIRE_TIME = 900
  
  class SAMLResponse

    attr_accessor :user_name, :email , :phone , :company , :title, :external_id, :error_message

    def initialize(valid, user_name, email, phone, company, title, external_id, error_message)
      @valid = valid
      @user_name = user_name
      @email = email
      @phone = phone
      @company = company
      @title = title
      @external_id = external_id
      @error_message = error_message ? error_message : ""
    end

    def valid?
      @valid
    end
  end

  class SsoFieldValidationError < StandardError
  end

  def sso_login_page_redirect
    #redirect to SSO login page
    sso_url = nil
    if current_account.is_saml_sso?
      settings = get_saml_settings(current_account)
      sso_url = OneLogin::RubySaml::Authrequest.new.create(settings)
    else
      sso_url = generate_sso_url(current_account.sso_login_url)
    end
    redirect_to sso_url
  end

  def get_saml_settings(acc)
    settings = OneLogin::RubySaml::Settings.new

    if current_account.features_included?(:saml_old_issuer)#backward compatibility
      settings.issuer = request.host
    else
      settings.issuer = "#{request.protocol}#{request.host}"
    end

    port = Rails.env.development? ? ":3000" : ""
    settings.assertion_consumer_service_url = "#{request.protocol}#{request.host}#{port}/login/saml"

    settings.idp_cert_fingerprint = acc.sso_options[:saml_cert_fingerprint]
    settings.idp_sso_target_url = acc.sso_login_url
    settings.idp_slo_target_url = acc.sso_logout_url unless acc.sso_logout_url.blank?
    settings.name_identifier_format = SAML_NAME_ID_FORMAT
    settings.name_identifier_format = SAML_NAME_ID_UNSPECIFIED if current_account.features?(:saml_unspecified_nameid)
    settings
  end


  def handle_sso_response(sso_data, relay_state_url)
    user_email_id = sso_data[:email]
    user_name = sso_data[:name]
    phone = sso_data[:phone]
    company = sso_data[:company]
    title = sso_data[:title]
    external_id = sso_data[:external_id]
    
    @current_user = current_account.users.where(:unique_external_id => external_id).first if external_id.present?
    if !@current_user
      unique_external_id_null_query = external_id.present? ? {users: {unique_external_id: nil}} : {}
      user_email = current_account.user_emails.includes(:user).where({email: user_email_id}.merge(unique_external_id_null_query)).first #unity media use case where emails need not be unique
      @current_user = user_email.user if user_email.present?
    end

    if @current_user && @current_user.deleted?
      cookies["mobile_access_token"] = { :value => 'failed', :http_only => true } if is_native_mobile?
      flash[:notice] = t(:'flash.login.deleted_user')
      redirect_to login_normal_url and return
    end

    if !@current_user
      options = sso_data

      @current_user = create_user(user_email_id,current_account,nil, options)
      @current_user.active = true
      saved = @current_user.save
    elsif current_account.sso_enabled?
      @current_user.name =  user_name
      @current_user.phone = phone unless phone.blank?
      @current_user.assign_company(company) if company.present?
      @current_user.job_title = title if title.present?
      if external_id.present?
        @current_user.unique_external_id = external_id
        @current_user.email = user_email_id
        @current_user.keep_user_active = true if @current_user.email_changed?
      end
      @current_user.active = true
      saved = @current_user.save
    end

    @current_user_session = @current_user.account.user_sessions.new(@current_user)
    @current_user_session.web_session = true unless is_native_mobile?
    if (!@current_user.new_record? && @current_user_session.save)
      if is_native_mobile?
        cookies["mobile_access_token"] = { :value => @current_user.mobile_auth_token, :http_only => true } 
        cookies["fd_mobile_email"] = { :value => @current_user.email, :http_only => true } 
      end
      remove_old_filters  if @current_user.agent?
      flash[:notice] = t(:'flash.login.success')
      if grant_day_pass(true)
        unless relay_state_url.blank?
          redirect_to relay_state_url
        else
          redirect_back_or_default(params[:redirect_to] || '/')
        end
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
  end

  def validate_saml_response(acc, saml_xml)

    user_name = user_email_id = phone = company = error_message = ""

    response = OneLogin::RubySaml::Response.new(saml_xml, :allowed_clock_drift => SSO_CLOCK_DRIFT)
    response.settings = get_saml_settings(acc)
    response.settings.issuer = nil
    valid_response = response.is_valid?

    if valid_response
      user_email_id = response.name_id
      user_name = response.attributes[:username] # default user name is actually just the part before @ in the email

      first_name = get_first_match(response.attributes , FIRST_NAME_STRS)
      last_name = get_first_match(response.attributes , LAST_NAME_STRS)
      phone = get_first_match(response.attributes , PHONE_NO_STRS)
      company = get_first_match(response.attributes , COMPANY_NAME_STRS)
      title = get_first_match(response.attributes , TITLE_STRS)
      external_id = get_first_match(response.attributes , EXTERNAL_ID_STRS)

      user_name = first_name if first_name
      user_name += " " + last_name if last_name
    else
      begin
        Rails.logger.debug("Got an invalid response from SAML Provider #{response.document}")
        Rails.logger.error("SAML Validation Error : #{response.errors}")
        error_message = " Validation Failed :  #{response.errors}"
      rescue Exception => e
        Rails.logger.error("SAML Validation Error : #{e.message}")
        NewRelic::Agent.notice_error(e, {:custom_params => {:error_message => e.message, :account_id => current_account.id}})
        error_message = " Validation Failed :  #{e.message}"
      end
    end
    SAMLResponse.new(valid_response, user_name, user_email_id, phone, company, title, external_id, error_message)
  end

  def generate_sso_url url
      return url if current_account.sso_options[:sso_type] == SAML
      host_url = "host_url=#{request.host}"
      url += (url.include? "?") ? "&#{host_url}" : "?#{host_url}"
      return url
  end

  def update_user_for_jwt_sso(account, user, user_fields, user_custom_fields, override)
    user_hash = ALLOWED_USER_DEFAULT_FIELDS.inject({}) do |uh, k| 
      if user_fields[k]
        raise SsoFieldValidationError if user_fields[k].class != String
        uh[k] = user_fields[k]
      end
      uh
    end
    if user.customer?
      allowed_custom_fields = account.contact_form.custom_non_dropdown_fields.map { |cf| [cf.name, cf.dom_type]  }
      allowed_custom_fields.map.each do |k|
        field_name = k[0][3..-1]
        if !user_custom_fields[field_name].nil?
          validate_custom_field(user_custom_fields[field_name], SSO_USER_CUSTOM_FIELD_MAPPING[k[1]])
          user_hash[k[0]] = user_custom_fields[field_name] 
        end
      end
    end

    user_hash.each do |key, value|
      if key == 'company_name' #no need to check if company exists as it will only add a company and not overwrite it.
        user.assign_company(value)
      else
        user.send("#{key}=", value) if !value.nil? && (override || user.send(key).nil?) 
      end
    end
    user.active = true
    user.keep_user_active = true if user.email_changed?
    user.save
  end

  def set_user_companies_for_jwt_sso(account, user, user_companies, overwrite)
    companies = user.companies
    company_names = companies.map { |c| c.name }
    if overwrite
      to_be_removed = company_names - user_companies
      remove_ids = to_be_removed.map{ |company_name| companies.find { |c| c.name == company_name}.id }
      UserCompany.destroy_all(:account_id => account.id,
                              :user_id => user.id,
                              :company_id => remove_ids) if remove_ids.any?
      user.user_companies.reload
    end

    to_be_added = user_companies - company_names
    to_be_added.each do |company_name|
      raise SsoFieldValidationError if company_name.class != String
      new_comp = account.companies.find_or_create_by_name(company_name)
      user.user_companies.build(:company_id => new_comp.id,
                                         :client_manager => false,
                                         :default => false)
    end
    user.save
  end

  def validate_custom_field(value, type)
    valid = true
    if type == Date
      begin
        DateTime.parse(value)
      rescue Exception => e
        valid = false
      end
    elsif type == "Boolean"
        valid = false if [true, false].exclude?(value)
    else
      valid = false if value.class != type
    end
    raise SsoFieldValidationError unless valid
  end

  private
  
    def get_first_match(attributes , keys)
      keys.each do |key|
        return attributes[key] if attributes[key]
      end
      return nil #not found
    end

end
