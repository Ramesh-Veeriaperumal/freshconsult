module OmniChannel::Util
  include OmniChannel::Constants

  def get_freshid_org_admin_user(account)
    org_domain = account.organisation_domain
    org_admin = {}
    freshid_account = Freshid::V2::Models::Account.find_by_domain(account.full_domain, org_domain)
    raise 'Account not found in Freshid' if freshid_account.blank? || freshid_account.id.blank?

    admin_users = Freshid::V2::Models::User.account_users(freshid_account.id, true, 1, nil, org_domain)
    org_admin = admin_users[:users].first if admin_users.present? && admin_users[:users].present?
    raise 'Organisation admin not found in Freshid' if org_admin.blank? || org_admin[:email].blank?

    org_admin_email = org_admin[:email]
    user = account.technicians.where(email: org_admin_email).first
    raise 'Current user not found' if user.blank?

    user
  end

  def bundle_signup_params(account, freshid_user, bundle_id, trial_end)
    organisation = account.organisation
    {
      user: {
        id: freshid_user.id,
        first_name: freshid_user.first_name,
        email: freshid_user.email,
        middle_name: freshid_user.middle_name,
        last_name: freshid_user.last_name
      },
      currency: account.subscription.currency.name,
      join_token: Freshid::V2::Models::Organisation.join_token,
      organisation: {
        id: organisation.organisation_id,
        domain: organisation.domain,
        name: organisation.name
      },
      misc: {
        bundle_name: SUPPORT_360_BUNDLE,
        bundle_id: bundle_id,
        trial_end: trial_end
      }
    }
  end

  def json_request_headers
    { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  end

  def signup_omni_account(signup_url, signup_params, product_name)
    response = HTTParty.post(signup_url, body: signup_params.to_json, headers: json_request_headers)
    Rails.logger.info("Response from omni account signup for account: #{Account.current.id} product #{product_name} is code: #{response.code}")
    response
  end

  def update_bundle_details(account_domain, org_domain, bundle_id, is_anchor = false)
    freshid_account = Freshid::V2::Models::Account.new(domain: account_domain)
    freshid_account.update({ bundle_identifier: bundle_id, anchor: is_anchor }, org_domain)
  end

  def schedule_bundle_updation_callback(account, account_domain)
    args = {
      account_id: account.id,
      organisation_domain: account.organisation_domain,
      account_domain: account_domain,
      freshid_account_params: {
        bundle_identifier: account.omni_bundle_id,
        anchor: false
      },
      retry_now: true
    }
    Freshid::V2::AccountDetailsUpdate.perform_async(args)
  end

  def schedule_agent_sync_callback(performer_id, product_name)
    args = {
      product_name: product_name,
      performer_id: performer_id
    }
    OmniChannelUpgrade::SyncAgents.perform_async(args)
  end

  def get_subscription_event(is_trial)
    is_trial ? SUBSCRIPTION_CHANGED : SUBSCRIPTION_ACTIVATED
  end

  def move_to_bundle_request_params(bundle_id)
    {
      bundle_id: bundle_id,
      bundle_name: SUPPORT_360_BUNDLE
    }
  end

  def move_freshcaller_to_bundle(bundle_id, freshcaller_account)
    request_params = move_to_bundle_request_params(bundle_id)
    move_to_bundle_url = "https://#{freshcaller_account.domain}/bundles/migrations/initiate"
    credentials = Freshid::V2::Auth.refresh_client_access_token.try(:credentials)
    response = send_request(:post, move_to_bundle_url, "Bearer #{credentials.access_token}", request_params)
    response
  end

  def send_request(req_type, url, auth, body, headers = nil, suppress_failure = false)
    request = Freshid::HttpServiceMethods.new(req_type, url, auth, body, headers, suppress_failure, timeout: 10)
    request.send_request
    request.response
  end

  def move_freshchat_to_bundle(bundle_id, freshchat_account, freshchat_jwt_token)
    request_params = move_to_bundle_request_params(bundle_id)
    response = HTTParty.post("https://#{freshchat_account.api_domain}/v2/omnichannel-integration/#{freshchat_account.app_id}/bundle",
                             body: request_params.to_json,
                             headers: json_request_headers.merge!(
                               'x-fc-client-id' => Freshchat::Account::CONFIG[:freshchatClient],
                               'Authorization' => "Bearer #{freshchat_jwt_token}"
                             ))
    response
  rescue StandardError => e
    Rails.logger.info "Error in move_freshchat_to_bundle #{e.inspect}"
    raise e
  end
end
