# encoding: utf-8
module SsoUtil
  SSO_TYPES = { saml: 'saml', simple_sso: 'simple', oauth2: 'oauth2', freshid_saml: 'freshid_saml'}.freeze
  FRESHDESK_SSO_TYPES = SSO_TYPES.slice(:saml, :simple_sso).freeze
  FRESHDESK_SAML_SSO_CONFIG_KEYS = ['saml_login_url', 'saml_logout_url', 'saml_cert_fingerprint'].freeze
  FRESHDESK_SIMPLE_SSO_CONFIG_KEYS = ['login_url', 'logout_url'].freeze
  FRESHID_SSO_EVENT_SAML = 'SAML'.freeze
  FRESHID_SSO_EVENT_OAUTH = 'OAUTH'.freeze
  FRESHID_SSO_EVENT_OIDC = 'OIDC'.freeze
  FRESHID_SSO_EVENT_TYPES = [FRESHID_SSO_EVENT_SAML, FRESHID_SSO_EVENT_OAUTH, FRESHID_SSO_EVENT_OIDC].freeze
  FRESHID_SSO_METHOD_MAP = {
      FRESHID_SSO_EVENT_SAML => 'freshid_saml',
      FRESHID_SSO_EVENT_OAUTH => 'oauth2',
      FRESHID_SSO_EVENT_OIDC => 'oidc'
  }

  FRESHID_AGENT_SAML_SSO = 'agent_freshid_saml'.freeze
  FRESHID_AGENT_OAUTH_SSO = 'agent_oauth2'.freeze
  FRESHID_AGENT_OIDC_SSO = 'agent_oidc'.freeze
  FRESHID_AGENT_DEFAULT_SSO = [FRESHID_AGENT_SAML_SSO, FRESHID_AGENT_OAUTH_SSO, FRESHID_AGENT_OIDC_SSO].freeze
  FRESHID_AGENT_CUSTOM_SSO = 'agent_custom_sso'.freeze
  FRESHID_AGENT_SSO = [FRESHID_AGENT_DEFAULT_SSO, FRESHID_AGENT_CUSTOM_SSO].flatten.freeze

  FRESHID_CONTACT_SAML_SSO = 'customer_freshid_saml'.freeze
  FRESHID_CONTACT_OAUTH_SSO = 'customer_oauth2'.freeze
  FRESHID_CONTACT_V1_SSO = [FRESHID_CONTACT_SAML_SSO, FRESHID_CONTACT_OAUTH_SSO].freeze
  FRESHID_CONTACT_CUSTOM_SSO = 'customer_custom_sso'.freeze
  FRESHID_CONTACT_SSO = [FRESHID_CONTACT_V1_SSO, FRESHID_CONTACT_CUSTOM_SSO].flatten.freeze

  FRESHID_SSO = [FRESHID_AGENT_SSO, FRESHID_CONTACT_SSO].flatten.freeze

  FRESHDESK_SAML_SSO = 'saml_login_url'.freeze
  FRESHDESK_SIMPLE_SSO = 'login_url'.freeze
  FRESHDESK_SSO = [FRESHDESK_SAML_SSO, FRESHDESK_SIMPLE_SSO].freeze

  SAML_NAME_ID_FORMAT = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'.freeze
  SAML_NAME_ID_UNSPECIFIED = 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'.freeze
  SSO_ALLOWED_IN_SECS = 1800
  SSO_CLOCK_DRIFT = 60 # No of secs the response time can be before the server time .. Keep this very low for security
  SSO_ALLOWED_IN_SECS_LIMITATION = 30 # No of seconds interval after which the sso login expires
  FIRST_NAME_STRS = ['givenname', 'FirstName', 'User.FirstName', 'username',
                     'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname'].map &:to_sym
  LAST_NAME_STRS = ['surname', 'LastName', 'User.LastName',
                    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname'].map &:to_sym
  PHONE_NO_STRS = [:phone].freeze
  COMPANY_NAME_STRS = [:organization, :company].freeze
  TITLE_STRS = [:title, :job_title].freeze
  EXTERNAL_ID_STRS = [:unique_id].freeze
  SAML_CUSTOM_FIELDS_PREFIX = 'custom_field_'.freeze
  ALLOWED_USER_DEFAULT_FIELDS = %w(name unique_external_id email company_name job_title time_zone language mobile phone).freeze
  SSO_USER_CUSTOM_FIELD_MAPPING = {
    number: Fixnum,
    url: 'URL',
    date: Date,
    phone_number: String,
    checkbox: 'Boolean',
    paragraph: String,
    text: String,
    dropdown_blank: String
  }.freeze

  SSO_MAX_EXPIRE_TIME = 900
  SAML_SSO_RESPONSE_SETTINGS = { allowed_clock_drift: SSO_CLOCK_DRIFT, skip_recipient_check: true }

  class SAMLResponse
    attr_accessor :user_name, :email, :phone, :company, :title, :external_id, :custom_fields, :error_message

    def initialize(valid, user_name, email, phone, company, title, external_id, custom_fields, error_message)
      @valid = valid
      @user_name = user_name
      @email = email
      @phone = phone
      @company = company
      @title = title
      @external_id = external_id
      @custom_fields = custom_fields
      @error_message = error_message ? error_message : ''
    end

    def valid?
      @valid
    end
  end

  class SsoFieldValidationError < StandardError
  end

  def sso_login_page_redirect
    # redirect to SSO login page
    sso_url = nil
    sso_url = if current_account.is_saml_sso?
      settings = get_saml_settings(current_account)
      OneLogin::RubySaml::Authrequest.new.create(settings)
    else
      generate_sso_url(current_account.sso_login_url)
    end
    redirect_to sso_url
  end

  def get_saml_settings(acc)
    settings = OneLogin::RubySaml::Settings.new

    settings.issuer = if current_account.features_included?(:saml_old_issuer) # backward compatibility
                        request.host
                      else
                        "#{request.protocol}#{request.host}"
                      end

    port = Rails.env.development? ? ':3000' : ''
    settings.assertion_consumer_service_url = "#{request.protocol}#{request.host}#{port}/login/saml"

    settings.idp_cert_fingerprint = acc.sso_options[:saml_cert_fingerprint]
    settings.idp_sso_target_url = acc.sso_login_url
    settings.idp_slo_target_url = acc.sso_logout_url unless acc.sso_logout_url.blank?
    settings.name_identifier_format = SAML_NAME_ID_FORMAT
    settings.name_identifier_format = SAML_NAME_ID_UNSPECIFIED if current_account.features?(:saml_unspecified_nameid)
    settings.idp_cert_fingerprint_algorithm = XMLSecurity::Document::SHA256 unless acc.launched?(:sha1_enabled)
    if current_account.launched?(:saml_ecrypted_assertion)
      settings.private_key = SAMLConfigs::SP_KEY
    end
    settings
  end

  def populate_sso_user_fields(account, user, user_fields, user_custom_fields, override)
    user_hash = ALLOWED_USER_DEFAULT_FIELDS.inject({}) do |uh, k|
      if user_fields[k]
        raise SsoFieldValidationError if user_fields[k].class != String
        uh[k] = user_fields[k]
      end
      uh
    end

    if user.customer?
      allowed_custom_fields = account.contact_form.custom_fields.map { |cf| [cf.name, cf.dom_type] }
      allowed_custom_fields.map.each do |k|
        field_name = k[0][3..-1]
        unless user_custom_fields[field_name].nil?
          validate_custom_field(field_name, user_custom_fields[field_name], SSO_USER_CUSTOM_FIELD_MAPPING[k[1]])
          user_hash[k[0]] = user_custom_fields[field_name]
        end
      end
    end

    user_hash.each do |key, value|
      if key == 'company_name' # no need to check if company exists as it will only add a company and not overwrite it.
        user.assign_company(value)
      else
        user.safe_send("#{key}=", value) if !value.nil? && (override || user.safe_send(key).nil?)
      end
    end
    user
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

  def handle_sso_response(sso_data, relay_state_url)
    user_email_id = sso_data[:email]
    user_name = sso_data[:name]
    phone = sso_data[:phone]
    company = sso_data[:company]
    title = sso_data[:title]
    external_id = sso_data[:external_id]

    @current_user = current_account.users.where(unique_external_id: external_id).first if external_id.present?
    unless @current_user
      unique_external_id_null_query = external_id.present? ? { users: { unique_external_id: nil } } : {}
      user_email = current_account.user_emails.includes(:user).where({ email: user_email_id }.merge(unique_external_id_null_query)).first # unity media use case where emails need not be unique
      @current_user = user_email.user if user_email.present?
    end

    if @current_user && @current_user.deleted?
      cookies['mobile_access_token'] = { value: 'failed', http_only: true } if is_native_mobile?
      flash[:notice] = t(:'flash.login.deleted_user')
      redirect_to(login_normal_url) && return
    end

    if !@current_user
      options = sso_data
      @current_user = create_user(user_email_id, current_account, nil, options)
    elsif current_account.sso_enabled?
      @current_user.name =  user_name
      @current_user.phone = phone unless phone.blank?
      @current_user.assign_company(company) if company.present?
      @current_user.job_title = title if title.present?
      if external_id.present?
        @current_user.unique_external_id = external_id
        @current_user.email = user_email_id
        @current_user.keep_user_active = true if @current_user.email_id_changed?
      end
    end
    populate_sso_user_fields(current_account, @current_user, {}, sso_data[:custom_fields], true) if sso_data[:custom_fields]
    @current_user.active = true
    saved = @current_user.save

    @current_user_session = @current_user.account.user_sessions.new(@current_user)
    @current_user_session.web_session = true unless is_native_mobile?
    if !@current_user.new_record? && @current_user_session.save
      DataDogHelperMethods.create_login_tags_and_send("saml_login", current_account, @current_user)
      if is_native_mobile?
        cookies['mobile_access_token'] = { value: @current_user.mobile_auth_token, http_only: true }
        cookies['fd_mobile_email'] = { value: @current_user.email, http_only: true }
      end
      remove_old_filters if @current_user.agent?
      # flash[:notice] = t(:'flash.login.success')
      if grant_day_pass(true)
        if relay_state_url.blank?
          redirect_back_or_default(params[:redirect_to] || '/')
        else
          redirect_to relay_state_url
        end
      else
        redirect_to login_normal_url
      end
    else
      Rails.logger.debug "User save status #{@current_user.errors.inspect}"
      Rails.logger.debug "User session save status #{@current_user_session.errors.inspect}"
      cookies['mobile_access_token'] = { value: 'failed', http_only: true } if is_native_mobile?
      flash[:notice] = t(:'flash.login.failed')
      redirect_to login_normal_url
    end
  end

  def validate_saml_response(acc, saml_xml)
    user_name = user_email_id = phone = company = error_message = ''

    response = OneLogin::RubySaml::Response.new(saml_xml, {settings: get_saml_settings(acc)}.merge(SAML_SSO_RESPONSE_SETTINGS))
    response.settings.issuer = nil
    valid_response = response.is_valid?

    if valid_response
      user_email_id = response.name_id
      attribs = response.attributes
      Rails.logger.info "SAML response attributes = #{attribs.inspect}"
      user_name = attribs[:username] # default user name is actually just the part before @ in the email

      first_name = get_first_match(attribs, FIRST_NAME_STRS)
      last_name = get_first_match(attribs, LAST_NAME_STRS)
      phone = get_first_match(attribs, PHONE_NO_STRS)
      company = get_first_match(attribs, COMPANY_NAME_STRS)
      title = get_first_match(attribs, TITLE_STRS)
      external_id = get_first_match(attribs, EXTERNAL_ID_STRS)

      custom_fields = extract_custom_fields(attribs)

      user_name = first_name if first_name
      user_name += ' ' + last_name if last_name
    else
      begin
        Rails.logger.debug("Got an invalid response from SAML Provider #{response.document}")
        Rails.logger.error("SAML Validation Error : #{response.errors}")
        error_message = " Validation Failed :  #{response.errors}"
      rescue Exception => e
        Rails.logger.error("SAML Validation Error : #{e.message}")
        NewRelic::Agent.notice_error(e, custom_params: {
                                       error_message: e.message, account_id: current_account.id
                                     })
        error_message = " Validation Failed :  #{e.message}"
      end
    end
    SAMLResponse.new(valid_response, user_name, user_email_id, phone,
                     company, title, external_id, custom_fields, error_message)
  end

  def generate_sso_url(url)
    return url if current_account.sso_options[:sso_type] == SSO_TYPES[:saml]
    host_url = "host_url=#{request.host}"
    url += (url.include? '?') ? "&#{host_url}" : "?#{host_url}"
    url
  end

  def update_user_for_jwt_sso(account, user, user_fields, user_custom_fields, override)
    user = populate_sso_user_fields(account, user, user_fields, user_custom_fields, override)
    user.active = true
    user.keep_user_active = true if user.email_id_changed?
    user.save
  end

  def set_user_companies_for_jwt_sso(account, user, user_companies, overwrite)
    user_companies = user_companies.compact.map(&:squish!)
    companies = user.companies
    company_names = companies.map(&:name)
    if overwrite
      to_be_removed = company_names - user_companies
      remove_ids = to_be_removed.map { |company_name| companies.find { |c| c.name == company_name }.id }
      UserCompany.destroy_all(account_id: account.id,
                              user_id: user.id,
                              company_id: remove_ids) if remove_ids.any?
      user.user_companies.reload
    end

    to_be_added = user_companies - company_names
    to_be_added.each do |company_name|
      raise SsoFieldValidationError, "Invalid company name" if company_name.class != String
      new_comp = account.companies.find_or_create_by_name(company_name)
      user.user_companies.build(company_id: new_comp.id,
                                client_manager: false,
                                default: false)
    end
    user.save
  end

  def validate_custom_field(field_name, value, type)
    if type == Date
      begin
        DateTime.parse(value)
      rescue Exception => e
        raise SsoFieldValidationError, "Invalid date #{field_name}=#{value}" 
      end
    elsif type == 'Boolean'
      raise SsoFieldValidationError, "Invalid checkbox value #{field_name}=#{value}" if ["true", "false"].exclude?(value.to_s)
    elsif type == 'URL'
      raise SsoFieldValidationError, "Invalid URL #{field_name}=#{value}" unless UriParser.valid_url?(value)
    elsif type == Fixnum
      raise SsoFieldValidationError, "Invalid number #{field_name}=#{value}" unless /^[-+]?\d+(.\d+)?$/ =~ value
    else
      raise SsoFieldValidationError, "Invalid #{type} #{field_name}=#{value}" if value.class != type
    end
  end

  private

    def get_first_match(attributes, keys)
      keys.each do |key|
        return attributes[key] if attributes[key]
      end
      nil # not found
    end

    def extract_custom_fields(attributes)
      custom_fields = {}
      attributes.each do |name, values|
        next unless name.start_with?(SAML_CUSTOM_FIELDS_PREFIX)
        cf_name = name.gsub(SAML_CUSTOM_FIELDS_PREFIX, '')
        cf_value = values.first
        custom_fields[cf_name] = cf_value
      end
      custom_fields
    end
end
