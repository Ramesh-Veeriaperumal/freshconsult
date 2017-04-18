require 'jwt'

class FdJWTAuth
  OPTIONS = {
    :JTI_MAX_EXPIRE_TIME => 3600,
    :IAT_MAX_EXPIRE_TIME => 60,
    :IAT_LEEWAY => 10,
    :ALGORITHM => 'HS256',
    :VERIFY_IAT => true
  }.freeze

  include Redis::RedisKeys
  include Redis::FdJWTAuthRedis

  def initialize(jwt_token, options={})
    @jwt_token = jwt_token
    @custom_options = OPTIONS.merge(options)
  end


  def decode_jwt_token
    begin
      parse_payload
      user = fetch_user
      decode_claim(user) if user
    rescue JWT::DecodeError => jwt_error
      Rails.logger.error "Error in validating claim : #{jwt_error.inspect} #{jwt_error.backtrace.join("\n\t")}"
    end
    user if user && validate?
  end

  private

  def parse_payload
    header_segment, payload_segment, claim_segment = @jwt_token.split('.')
    begin
      @payload = JSON.parse(JWT.base64url_decode(payload_segment), :symbolize_names => true) 
    rescue JSON::ParserError 
      raise JWT::DecodeError, 'Invalid segment encoding' 
    end
  end

  def fetch_user
    user = Account.current.users.where(id: @payload[:user_id]).first
    user if user and user.valid_user? and user.agent?
  end

  def decode_claim(user)
    @decoded_claim = (JWT.decode @jwt_token, user.single_access_token, true,
                                  { :verify_iat => @custom_options[:VERIFY_IAT],:iat_leeway => @custom_options[:IAT_LEEWAY], :algorithm => @custom_options[:ALGORITHM],
                                    :verify_jti => proc { |jti| valid_jti?(jti) }})[0].symbolize_keys
  end

  def validate?
    valid_claims? and expired_jwt_token?
  end

  def valid_claims?
    @payload == @decoded_claim and @decoded_claim[:user_id].present? and @decoded_claim[:account_id] == Account.current.id
  end

  def valid_jti?(jti)
    key = JWT_API_JTI % { :account_id => Account.current.id, :user_id =>  @payload[:user_id], :jti => jti }
    expiry_time = {:ex => @custom_options[:JTI_MAX_EXPIRE_TIME]}
    true if !redis_key_exists?(key) and set_jwt_redis_with_expiry(key, @payload[:iat], expiry_time)
  end

  def expired_jwt_token?
    Time.now.to_i - @payload[:iat] < @custom_options[:IAT_MAX_EXPIRE_TIME]
  end


end
