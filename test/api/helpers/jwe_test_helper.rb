module JweTestHelper
  def generate_custom_jwe_token(payload, source_name, expiration = CHANNEL_API_CONFIG[source_name][:jwt_default_expiry])
    payload = payload.dup
    payload['exp'] = Time.now.to_i + expiration.to_i if expiration
    jwt = JWT.encode(payload, CHANNEL_API_CONFIG[source_name]['jwt_secret'])
    JWE.encrypt(jwt, CHANNEL_API_CONFIG[source_name]['secret_key'], alg: 'dir', source: source_name)
  end

  def set_jwe_auth_header(source_name)
    request.env['X-Channel-Auth'] = generate_custom_jwe_token({}, source_name)
  end
end
