module Bot::Authentication
  TOKEN_REGEX = /Bearer (.*)/

  def authenticate_request
    auth = request.headers['Authorization']
    auth = auth.match(TOKEN_REGEX) unless auth.nil?
    token = auth[1] if !auth.nil? and auth.length > 1
    render_request_error(:access_denied, 403) unless token.present? && verify(token)
  end

  def verify(token)
    begin
      jwt = JWE.decrypt(token, BOT_JWE_SECRET)
      JWT.decode(jwt, BOT_JWT_SECRET)
    rescue JWE::DecodeError, JWE::NotImplementedError, JWE::BadCEK, JWE::InvalidData, JWT::ImmatureSignature, JWT::ExpiredSignature, JWT::DecodeError => exception
      Rails.logger.error(exception)
      return false
    end
    true
  end
end
