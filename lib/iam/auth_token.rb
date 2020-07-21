module Iam::AuthToken
  PRIVATE_KEY = OpenSSL::PKey::RSA.new(File.read('config/cert/iam.pem'), ::Iam::IAM_CONFIG['password'])
  def construct_jwt(user)
    payload = {
      user_id: user.id.to_s,
      account_id: Account.current.id.to_s,
      product: 'freshdesk',
      account_domain: Account.current.full_domain,
      privileges: user.privileges.to_s,
      iat: Time.now.to_i,
      exp: Time.now.to_i + ::Iam::IAM_CONFIG['expiry'].to_i,
      iss: 'fd-iam-service'
    }
    payload[:type] = user.helpdesk_agent? ? 'agent' : 'contact'
    payload[:org_user_id] = user.freshid_authorization.uid if user.helpdesk_agent? && user.freshid_authorization.try(:provider) == 'freshid'
    payload[:org_id] = Account.current.organisation_account_mapping.organisation_id.to_s if Account.current.organisation_account_mapping.present?
    headers = {
      'kid' => ::Iam::IAM_CONFIG['kid'],
      'typ' => 'JWT',
      'alg' => 'RS256'
    }
    'Bearer ' + JWT.encode(payload, PRIVATE_KEY, 'RS256', headers)
  end
end
