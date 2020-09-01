module JwtTestHelper
  TWITTER = 'twitter'.freeze
  PROACTIVE = 'proactive'.freeze
  FRESHMOVER = 'freshmover'.freeze
  FREDDY = 'freddy'.freeze
  FRESHCONNECT = 'freshconnect'.freeze
  SHERLOCK = 'sherlock'.freeze
  FRESHCHAT = 'freshchat'.freeze
  FACEBOOK = 'facebook'.freeze
  FRESHBOTS = 'freshbots'.freeze
  TWILIGHT = 'twilight'.freeze
  FIELD_SERVICE = 'field_service'.freeze
  FRESHDESK = 'freshdesk'.freeze
  SILKROAD = 'silkroad'.freeze
  ANALYTICS = 'analytics'.freeze
  FRESHDESK = 'freshdesk'.freeze
  SEARCH = 'search'.freeze
  JWT_SECRET_SOURCES = [TWITTER, PROACTIVE, FRESHMOVER, FRESHCONNECT, SHERLOCK, FACEBOOK, FRESHBOTS, TWILIGHT, FIELD_SERVICE].freeze
  JWT_ARRAY_SECRET_SOURCES = [FREDDY, FRESHCHAT, SILKROAD, ANALYTICS, FRESHDESK, SEARCH].freeze

  def generate_jwt_token(user_id, account_id, jti, iat, algorithm = 'HS256')
    payload = {:jti => jti, :iat => iat,
               :user_id => user_id, :account_id => account_id}
    single_access_token = @account.users.find_by_id(payload[:user_id]).single_access_token
    JWT.encode payload, single_access_token, algorithm
  end

  def generate_custom_jwt_token(source_name)
    return generate_freddy_jwt(source_name) if JWT_ARRAY_SECRET_SOURCES.include?(source_name)
    return generate_jwt_for_jwt_secret_sources(source_name) if JWT_SECRET_SOURCES.include?(source_name)
    return generate_jwt_token_for_privilege(source_name) if source_name == FRESHDESK

    domain = @account.full_domain.split('.')[0]
    account_details = { 'domain_name' => domain,
                        'timestamp' => Time.now.iso8601 }.to_json
    encrypted_payload = Encryptor.encrypt(account_details,
                                         key: CHANNEL_API_CONFIG[source_name]['secret_key'],
                                         iv:CHANNEL_API_CONFIG[source_name]['iv'])
    encoded_payload = Base64.encode64(encrypted_payload)
    payload = {:enc_payload =>encoded_payload}
    custom_jwt = JWT.encode payload, CHANNEL_API_CONFIG[source_name]['jwt_secret'], 'HS256', {:source=>source_name}
    custom_jwt
  end

  def generate_jwt_for_jwt_secret_sources(source_name)
    payload = { enc_payload: { 'account_id' => @account.id, 'timestamp' => Time.now.iso8601 } }
    JWT.encode payload, CHANNEL_API_CONFIG[source_name.to_sym][:jwt_secret], 'HS256', source: source_name
  end

  def generate_freddy_jwt(source_name)
    payload = { enc_payload: { 'source' => source_name, 'timestamp' => Time.now.iso8601 } }
    JWT.encode payload, CHANNEL_API_CONFIG[source_name.to_sym][:jwt_secret][0], 'HS256', source: source_name
  end

  def set_jwt_auth_header(source)
    request.env['X-Channel-Auth'] = generate_custom_jwt_token(source)
  end

  def get_mobile_jwt_token_of_user(user)
    user.mobile_auth_token
  end

  def set_custom_jwt_header(token)
    request.env["HTTP_AUTHORIZATION"] = token
  end

  def generate_app_jwt_token(product_account_id, jti, iat, app_name, algorithm = 'HS256')
    payload = { jti: jti,
                iat: iat,
                product_account_id: product_account_id,
                app_name: app_name }
    single_access_token = APP_INTEGRATION_CONFIG['freshconnect']['token']
    JWT.encode payload, single_access_token, algorithm
  end

  def generate_iam_jwt_token(user, private_key, exp = nil)
    payload = { user_id: user.id.to_s,
                account_id: Account.current.id.to_s,
                product: 'freshdesk',
                account_domain: Account.current.full_domain,
                privileges: user.privileges.to_s,
                iat: Time.now.to_i,
                exp: exp || Time.now.to_i + ::Iam::IAM_CONFIG['expiry'].to_i }
    payload[:type] = user.helpdesk_agent? ? 'agent' : 'contact'
    payload[:org_user_id] = user.freshid_authorization.uid if user.helpdesk_agent? && user.freshid_authorization.try(:provider) == 'freshid'
    payload[:org_id] = Account.current.organisation_account_mapping.organisation_id if Account.current.organisation_account_mapping.present?
    headers = { kid: ::Iam::IAM_CONFIG['kid'],
                typ: 'JWT',
                alg: 'RS256' }
    JWT.encode(payload, private_key, 'RS256', headers)
  end

  def generate_jwt_token_for_privilege(source_name)
    payload = { account_id: Account.current.id, domain: Account.current.full_domain, current_user_id: User.current.id }
    JWT.encode payload, source_name, 'HS256', 'alg' => 'HS256'
  end
end
