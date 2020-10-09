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

  def freshcaller_request(params, path, request_type, payload = {})
    options = {
      :headers => {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Freshdesk token=#{sign_payload(payload)}"
      }
    }
    
    if params.key?(:headers)
      options[:headers].merge!(params.delete(:headers))
    end

    if request_type == :get
      options.merge!({:query => params})
    else
      options.merge!({:body => params.to_json})
    end
    Rails.logger.info "Freshcaller Request Params :: #{HTTP_METHOD_TO_CLASS_MAPPING[request_type]} #{URI.encode(path)} #{options.inspect}"
    options[:verify_blacklist] = true
    request = HTTParty::Request.new(HTTP_METHOD_TO_CLASS_MAPPING[request_type], URI.encode(path), options)
    freshcaller_response = request.perform
    Rails.logger.info "Freshcaller Response :: #{freshcaller_response.body} #{freshcaller_response.code} #{freshcaller_response.message} #{freshcaller_response.headers.inspect}"
    freshcaller_response
  end
  
  def auth_hash
    payload = { email: current_user.email }
    params[:jwt_token].present? ? FRESHCALLER_JWTTOKEN_PREFIX + params[:jwt_token].to_s : HELPKIT_JWTTOKEN_PREFIX + sign_payload(payload)
  end

  def custom_authenticate_request
    render_request_error :credentials_required, Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized] if nil_headers?
    custom_auth_headers? ? authenticate_jwt_request : fallback_to_app_authentication
  end

  def nil_headers?
    request.headers['Authorization'].blank?
  end

  def custom_auth_headers?
    !request.headers['Authorization'].starts_with?('Basic')
  end

  def authenticate_jwt_request
    auth_secret = request.headers['Authorization']
    auth_secret = auth_secret.match(TOKEN_REGEX) unless auth_secret.nil?
    auth_secret = auth_secret[1].strip if !auth_secret.nil? and auth_secret.length > 1
    payload = verify(auth_secret)
    if payload.blank? || payload['api_key'].blank?
      render_request_error :invalid_credentials, Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
    end
    set_user(payload) if @load_current_user
  end

  def set_user(payload)
    user = current_account.technicians.find_by_single_access_token(payload['api_key'])
    return (@current_user = user) && user.make_current if user.present?
    render_request_error :invalid_credentials, Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
  end

  def fallback_to_app_authentication
    check_privilege
    check_day_pass_usage_with_user_time_zone
    set_current_account
  end

  def protocol
    Rails.env.development? ? 'http://' : 'https://'
  end
end
