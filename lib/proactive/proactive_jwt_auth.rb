module Proactive::ProactiveJwtAuth
  def sign_payload(payload = {}, expiration = ProactiveServiceConfig['jwt_default_expiry'])
    payload['exp'] = Time.now.to_i + expiration.to_i if expiration
    JWT.encode(payload, ProactiveServiceConfig['signing_key'])
  end
end
