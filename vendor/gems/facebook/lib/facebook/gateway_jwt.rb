module Facebook::GatewayJwt
  def sign_payload(payload = {}, expiration = FacebookGatewayConfig['jwt_default_expiry'])
    payload['exp'] = Time.now.to_i + expiration.to_i if expiration
    JWT.encode(payload, FacebookGatewayConfig['jwt_secret'])
  end
end
