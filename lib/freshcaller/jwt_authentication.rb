module Freshcaller::JwtAuthentication
  include Freshcaller::Constants
  TOKEN_REGEX = /token=(.*)/

  def verify(token)
    return if token.nil?
    payload = nil
    FreshfoneConfig['verification_keys'].each {|jwt_secret|
      begin
        break unless payload.nil?
        jwt = JWE.decrypt(token, jwt_secret)
        payload = JWT.decode(jwt, jwt_secret).first
      rescue JWE::DecodeError, JWE::NotImplementedError, JWE::BadCEK, JWE::InvalidData, JWT::ImmatureSignature, JWT::ExpiredSignature, JWT::DecodeError => e
        payload = nil
      end
    }
    return payload
  end

  def sign_payload(payload, expiration=FreshfoneConfig['jwt_default_expiry'])
    payload = payload.dup
    payload['exp'] = Time.now.to_i + expiration.to_i if expiration
    jwt = JWT.encode(payload, FreshfoneConfig['signing_key'])
    JWE.encrypt(jwt, FreshfoneConfig['signing_key'], alg: 'dir')
  end

  def auth_hash
    payload = { email: current_user.email }
    params[:jwt_token].present? ? FRESHCALLER_JWTTOKEN_PREFIX + params[:jwt_token].to_s : HELPKIT_JWTTOKEN_PREFIX + sign_payload(payload)
  end

  def custom_authenticate_request
    auth_secret = request.headers['Authorization']
    auth_secret = auth_secret.match(TOKEN_REGEX) unless auth_secret.nil?
    auth_secret = auth_secret[1].strip if !auth_secret.nil? and auth_secret.length > 1
    render_request_error(:access_denied, 403) unless verify(auth_secret)
  end
end
