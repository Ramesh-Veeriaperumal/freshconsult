module Freshchat::JwtAuthentication
  JWT_ALGO = 'HS256'.freeze
  def freshchat_jwt_token
    JWT.encode sync_freshchat_payload, Freshchat::Account::CONFIG[:freshchatSharedKey], JWT_ALGO
  end

  private

    def sync_freshchat_payload
      {}.tap do |claims|
        claims[:app_id] = Account.current.freshchat_account.app_id
        claims[:iat] = Time.zone.now.to_i
        claims[:exp] = Time.zone.now.to_i + 1.minute
        claims[:iss] = Freshchat::Account::CONFIG[:issuer]
        claims[:bundle_id] = Account.current.omni_bundle_id
        # Need to org_id here as part of claim for omni bundle support
      end
    end
end
