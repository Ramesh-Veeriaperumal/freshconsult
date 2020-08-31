module Iam::AuthToken
  include Channel::V2::Iam::AuthenticationConstants

  PRIVATE_KEY = OpenSSL::PKey::RSA.new(File.read('config/cert/iam.pem'), ::Iam::IAM_CONFIG['password'])

  def construct_jwt(user, privilege_data = nil)
    payload = {
      user_id: user.id.to_s,
      account_id: Account.current.id.to_s,
      product: 'freshdesk',
      account_domain: Account.current.full_domain,
      privileges: privilege_data.present? ? construct_privilege(privilege_data) : user.privileges.to_s,
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
    JWT.encode(payload, PRIVATE_KEY, 'RS256', headers)
  end

  def construct_client_jwt(source, privilege_data = nil)
    payload = {
      sub: source.presence,
      product: 'freshdesk',
      privileges: privilege_data.present? ? construct_privilege(privilege_data) : '0',
      iat: Time.now.to_i,
      exp: Time.now.to_i + ::Iam::IAM_CONFIG['expiry'].to_i,
      iss: 'fd-iam-service',
      type: 'client'
    }
    payload[:org_id] = Account.current.organisation_account_mapping.organisation_id.to_s if Account.current.organisation_account_mapping.present?
    headers = {
      'kid' => ::Iam::IAM_CONFIG['kid'],
      'typ' => 'JWT',
      'alg' => 'RS256'
    }
    JWT.encode(payload, PRIVATE_KEY, 'RS256', headers)
  end

  def construct_jwt_with_bearer(user)
    "#{BEARER} #{construct_jwt(user)}"
  end

  def construct_channel_jwt_with_bearer(source)
    "#{BEARER} #{construct_client_jwt(source)}"
  end

  def construct_privilege(privilege_data)
    (privilege_data & PRIVILEGES_BY_NAME).map { |r| 2**PRIVILEGES[r] }.sum
  end
end
