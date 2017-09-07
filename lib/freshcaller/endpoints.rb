module Freshcaller::Endpoints
  include Freshcaller::JwtAuthentication

  def freshcaller_admin_rules_url
    "https://#{current_account.freshcaller_account.domain}/sso/helpkit/#{sign_payload(email: current_user.email)}?redirect_path=/admin/rules"
  end
end
