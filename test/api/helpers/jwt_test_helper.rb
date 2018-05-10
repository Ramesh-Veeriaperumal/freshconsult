module JwtTestHelper

  def generate_jwt_token(user_id, account_id, jti, iat, algorithm = 'HS256')
    payload = {:jti => jti, :iat => iat,
               :user_id => user_id, :account_id => account_id}
    single_access_token = @account.users.find_by_id(payload[:user_id]).single_access_token
    JWT.encode payload, single_access_token, algorithm
  end

  def generate_custom_jwt_token(source_name)
    domain = @account.full_domain.split('.')[0]
    account_details = {"domain_name": domain,
                     "timestamp":Time.now.iso8601
                     }.to_json
    encrypted_payload = Encryptor.encrypt(account_details,
                                         key: CHANNEL_API_CONFIG[source_name]['secret_key'],
                                         iv:CHANNEL_API_CONFIG[source_name]['iv'])
    encoded_payload = Base64.encode64(encrypted_payload)
    payload = {:enc_payload =>encoded_payload}
    custom_jwt = JWT.encode payload, CHANNEL_API_CONFIG[source_name]['jwt_secret'], 'HS256', {:source=>source_name}
    custom_jwt
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

end