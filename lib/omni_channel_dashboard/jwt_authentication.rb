class OmniChannelDashboard::JwtAuthentication
  include OmniChannelDashboard::Constants

  def jwt_token
    JWT.encode jwt_payload, OmniChannelDashboardConfig['signing_key'], JWT_ALGO
  end

  private

    def jwt_payload
      {}.tap do |claims|
        claims[:iss] = ISSUER
        claims[:iat] = Time.zone.now.to_i
        claims[:exp] = Time.zone.now.to_i + EXPIRY_DURATION
        claims[:bundle_id] = Account.current.omni_bundle_id
      end
    end
end
