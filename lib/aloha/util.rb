module Aloha::Util
  include Aloha::Constants
  include Aloha::Validations
  include Freshchat::Util
  include Freshcaller::Util

  def verify_aloha_token
    unless Rails.env.test?
      if request.headers && request.headers['HTTP_AUTHORIZATION']
        auth = request.headers['HTTP_AUTHORIZATION'].strip.split(' ')
        token = auth[1] if auth.length == 2 && auth[0].downcase == 'bearer'
      end
      decoded_token = JWT.decode token, nil, false
      kid = decoded_token[1]["kid"]
      rsa_public = get_public_key(kid)
      JWT.decode token, rsa_public, true, algorithm: 'RS256'
    end
  end

  def get_public_key(kid)
    jwks_raw = Net::HTTP.get URI AlohaConfig[:jwks_url]
    jwk = JSON.parse(jwks_raw)
    jwk = JSON::JWK.new(jwk['keys'].select { |x| x['kid'] == kid }.first)
    jwk['n'] += '=' * (4 - jwk['n'].length.modulo(4))
    jwk.to_key
  end

  def send_updated_access_token_to_chat
    current_account = Account.current
    fc_acc = current_account.freshchat_account
    return if fc_acc.nil?
    response = update_access_token(current_account.domain, admin_access_token, fc_acc, freshchat_jwt_token)
    aloha_linking_error_logs UPDATE_FRESHCHAT_ACCESS_TOKEN_CODE if response.code != 200
    response
  end

  def send_updated_access_token_to_caller
    current_account = Account.current
    freshcaller_account = current_account.freshcaller_account
    freshcaller_params = {
      'account' => { 'domain' => freshcaller_account.domain },
      'bundle_id' => current_account.omni_bundle_id
    }
    account_admin = current_account.account_managers.first
    link_params = freshcaller_bundle_linking_params(current_account, account_admin.email, account_admin.single_access_token, freshcaller_params)
    send_access_token_to_caller(freshcaller_account.domain, link_params)
  end

  def admin_access_token
    Account.current.users.find_by_email(Account.current.admin_email).single_access_token
  end

  def aloha_linking_error_logs(errorcode)
    Rails.logger.info "Aloha - Bundle Linking API error - #{errorcode} :: #{Account.current.id} :: #{Account.current.omni_bundle_id}"
  end
end
