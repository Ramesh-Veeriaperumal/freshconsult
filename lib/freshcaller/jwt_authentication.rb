module Freshcaller::JwtAuthentication
  
  HTTP_METHOD_TO_CLASS_MAPPING = {
    get: Net::HTTP::Get,
    post: Net::HTTP::Post,
    put: Net::HTTP::Put,
    delete: Net::HTTP::Delete,
    patch: Net::HTTP::Patch
  }.freeze
  
  include Freshcaller::Constants
  TOKEN_REGEX = /token=(.*)/

  def verify(token)
    return if token.nil?
    payload = nil
    FreshcallerConfig['verification_keys'].each do |jwt_secret|
      begin
        break unless payload.nil?
        jwt = JWE.decrypt(token, jwt_secret)
        payload = JWT.decode(jwt, jwt_secret).first
      rescue JWE::DecodeError, JWE::NotImplementedError, JWE::BadCEK, JWE::InvalidData, JWT::ImmatureSignature, JWT::ExpiredSignature, JWT::DecodeError => e
        payload = nil
      end
    end
    payload
  end

  def sign_payload(payload = {}, expiration = FreshcallerConfig['jwt_default_expiry'])
    payload = payload.dup
    payload['exp'] = Time.now.to_i + expiration.to_i if expiration
    jwt = JWT.encode(payload, FreshcallerConfig['signing_key'])
    JWE.encrypt(jwt, FreshcallerConfig['signing_key'], alg: 'dir')
  end

  # def signed_payload(expiration = FreshcallerConfig['jwt_default_expiry'])
  #   payload = { email: ::User.current.email }
  #   'Helpkit token=' + sign_payload(payload, expiration)
  # end
  
  def freshcaller_request(params, path, request_type, payload = {})
    options = {
      :headers => {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Helpkit token=#{sign_payload(payload)}"
      },
      :query => params
    }

    request = HTTParty::Request.new(HTTP_METHOD_TO_CLASS_MAPPING[request_type], URI.encode(path), options)
    request.perform
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
