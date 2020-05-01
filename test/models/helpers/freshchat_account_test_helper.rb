module FreshchatAccountTestHelper
  def create_freshchat_account account
    return account.create_freshchat_account(
      app_id: SecureRandom.uuid,
      enabled: true,
      domain: account.freshid_org_v2_enabled? ? "#{account.domain}.freshchat.com" : nil
    )
  end

  def freshchat_account_publish_pattern fchat_account
    {
      id: fchat_account.id,
      freshdesk_account_id: fchat_account.account_id,
      freshchat_account_id: fchat_account.app_id,
      freshchat_domain: fchat_account.api_domain,
      freshchat_account_domain: fchat_account.domain,
      preferences: fchat_account.preferences,
      enabled: fchat_account.enabled,
      created_at: fchat_account.created_at.try(:utc).try(:iso8601),
      updated_at: fchat_account.updated_at.try(:utc).try(:iso8601)
    }
  end

  def model_changes_freshchat_account_enabled old_value, new_value
    {
      "enabled" => [old_value, new_value]
    }
  end

  def freshchat_account_destroy_pattern fchat_account
    {
      freshdesk_account_id: fchat_account.account_id,
      freshchat_account_id: fchat_account.app_id
    }
  end
end