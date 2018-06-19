require 'jwt'

class AppJWTAuth
  CLAIMS = {
    IAT_LEEWAY: 10,
    IAT_MAX_EXPIRE_TIME: 60,
    ALGORITHM: 'HS256',
    VERIFY_IAT: true
  }.freeze

  APP_NAMES   = APP_INTEGRATION_CONFIG.keys.freeze
  TOKEN_REGEX = /JWTAuth token=(.*)/

  attr_accessor :payload # :app_name might be required

  def initialize(header, options = {})
    @auth_secret    = header
    @custom_options = CLAIMS.merge(options)
  end

  def decode_jwt_token
    if @auth_secret.present?
      begin
        parsed_token = @auth_secret.match(TOKEN_REGEX)
        @jwt_token   = parsed_token[1].strip if parsed_token.present? && parsed_token.length > 1
        if @jwt_token
          parse_payload
          decode_claim
        end
      rescue JWT::DecodeError => jwt_error
        Rails.logger.error "Error in validating claim : #{jwt_error.inspect} #{jwt_error.backtrace.join("\n\t")}"
      end
    end
  end

  def verify_auth?
    valid_claims? && expired_jwt_token?
  end

  private

    def parse_payload
      _header_segment, payload_segment, _claim_segment = @jwt_token.split('.')
      @payload = JSON.parse(JWT.base64url_decode(payload_segment), symbolize_names: true)
    rescue JSON::ParserError
      raise JWT::DecodeError, 'Invalid segment encoding'
    end

    def decode_claim
      # for now the config has only freshconnect...Has to be made little generic
      @decoded_claim = (JWT.decode @jwt_token, shared_secret, true, algorithm: @custom_options[:ALGORITHM])[0].symbolize_keys
    end

    def valid_claims?
      @decoded_claim &&
        @decoded_claim == @payload &&
          APP_NAMES.include?(@decoded_claim[:app_name])
    end

    def expired_jwt_token?
      Time.now.to_i - @payload[:iat] < @custom_options[:IAT_MAX_EXPIRE_TIME]
    end

    def shared_secret
      APP_INTEGRATION_CONFIG['freshconnect']['token']

      # app_name = @payload[:app_name]
      # APP_INTEGRATION_CONFIG[app_name]['token'] if APP_NAMES.include?(app_name) # need to handle  nil case
    end
end
