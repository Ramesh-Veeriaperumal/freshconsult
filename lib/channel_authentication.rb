module ChannelAuthentication
  TYPE_JWE = 'jwe'.freeze
  TYPE_JWT = 'jwt'.freeze
  CHANNELS = {
    twitter: 'twitter'.freeze,
    zapier: 'zapier'.freeze,
    proactive: 'proactive'.freeze
  }.freeze

  def channel_client_authentication
    auth_token = header_token
    if auth_token
      config = auth_token[:config]
      payload = verify_token(auth_token,config)
      decrypt_payload(payload, config) if payload.present? && auth_token[:source] == CHANNELS[:zapier]
    else
      invalid_credentials_error unless params[:controller] == 'channel/tickets'
    end
  end

  private

    def verify_token(auth_token,config)
      jwt_token = config[:auth_type] == TYPE_JWE ? jwe_decryption(auth_token[:token],config[:secret_key]) : auth_token[:token];
      verified_payload = jwt_verify(jwt_token, config[:jwt_secret], 'HS256') if jwt_token.present?
      verified_payload.present? ? verified_payload : invalid_credentials_error
    end  

    def jwe_decryption(token,key)
      JWE.decrypt(token,key)
    end

    def decrypt_payload(verified_payload,config)
      decode_payload = Base64.decode64(verified_payload[:enc_payload])
      payload = Encryptor.decrypt(value: decode_payload,
                        key: config[:secret_key],
                        iv: config[:iv]) || {}
    
      payload.present? ? token_domain_check(payload) : invalid_credentials_error
    end

    def jwt_verify(token, key, algo)
      begin
        JWT.decode(token, key, true, algorithm: algo).first.symbolize_keys
      rescue JWE::DecodeError, JWE::NotImplementedError, JWE::BadCEK, JWE::InvalidData, JWT::ImmatureSignature, JWT::ExpiredSignature, JWT::DecodeError => exception
        Rails.logger.error(exception)
        nil
      end
    end

    def channel_twitter?
      source(request.headers['X-Channel-Auth']) == CHANNELS[:twitter]
    rescue StandardError => e
      invalid_credentials_error
    end

    def channel_proactive?
      source(request.headers['X-Channel-Auth']) == CHANNELS[:proactive]
    rescue StandardError => e
      invalid_credentials_error
    end

    def header_token
      # expected header format => X-Channel-Auth: <enc_type xx.xx.xx>
      token = request.headers['X-Channel-Auth']
      source_name = source(token)
      config = CHANNEL_API_CONFIG.fetch(source_name, {}) if source_name.present?
      return { token: token, source: source_name, config: config } if config
    rescue
      nil
    end 

    def token_domain_check(payload)
      invalid_credentials_error unless Account.current.domain == JSON.parse(payload)["domain_name"]
    end

    def invalid_credentials_error
      render_request_error :invalid_credentials, 401
      nil
    end

    def source(token)
      return @source if @source.present?

      return if token.blank?
      jwt_header = token.split('.')[0]
      @source = JSON.parse(Base64.decode64(jwt_header))['source'] if jwt_header
    end
end
