module Reports::Freshvisuals
    def jwt_auth_token
      JWT.encode freshreports_payload, FreshVisualsConfig['secret_key'], 'HS256', 'alg' => 'HS256', 'typ' => 'JWT'
    end

    def freshreports_payload
      {
        firstName: current_user.name,
        email: current_user.email,
        timezone: TimeZone.fetch_tzinfoname,
        tenantId: current_account.id,
        portalUrl: "#{current_account.url_protocol}://#{current_account.full_domain}",
        userId: current_user.id,
        sessionExpiration: Time.now.to_i + FreshVisualsConfig['session_expiration'].to_i,
        iat: Time.now.to_i,
        exp: Time.now.to_i + FreshVisualsConfig['session_expiration'].to_i
      }
    end
end