class JWTAuthentication
  attr_accessor :token, :secret_key, :expire_at, :source, :payload, :errors, :error_options

  DEFAULT_EXPIRY = 1.hour
  DEFAULT_LEEWAY = 0
  EXPIRE_AT_FORMAT = '%Y-%m-%dT%H:%M:%SZ'.freeze

  def initialize(source: '', token: '', secret_key: '')
    self.source = source
    self.token = token
    self.secret_key = secret_key
  end

  def authenticate
    parse_payload
    if payload.present?
      jwt_payload_validation = JwtPayloadValidation.new(payload, expiry)
      if jwt_payload_validation.valid?(source.to_sym)
        set_expiry
      else
        assign_errors(custom_errors: jwt_payload_validation.errors, error_options: jwt_payload_validation.error_options)
      end
    end
    self
  end

  private

    def parse_payload
      self.payload = JWT.decode(token, secret_key, true, 'leeway' => leeway).first.symbolize_keys
    rescue JWE::DecodeError, JWE::NotImplementedError, JWE::BadCEK, JWE::InvalidData, JWT::ImmatureSignature, JWT::DecodeError, JWT::InvalidIatError, JWT::ExpiredSignature => exception
      Rails.logger.error(exception)
      assign_errors(key: 'token', message: exception.message, error_options: { code: :unauthorized })
    end

    def expiry
      @expiry ||= begin
        key = "#{source}_expiry".upcase
        "JWTConstants::#{key}".constantize || DEFAULT_EXPIRY
      end
    end

    def leeway
      key = "#{source}_leeway".upcase
      "JWTConstants::#{key}".constantize || DEFAULT_LEEWAY
    end

    def set_expiry
      @expire_at = Time.at(payload[:exp]).utc.to_datetime.strftime(EXPIRE_AT_FORMAT)
    end

    def assign_errors(custom_errors: nil, error_options: nil, key: nil, message: nil)
      @errors = custom_errors || ActiveModel::Errors.new(Object.new)
      errors.messages[key.to_sym] = [message] if key && message
      @error_options = error_options
    end
end
