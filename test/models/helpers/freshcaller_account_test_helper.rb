module FreshcallerAccountTestHelper
  def create_freshcaller_account account
    return account.create_freshcaller_account(
      freshcaller_account_id: Faker::Number.number(6),
      domain: "#{Faker::Lorem.characters(8)}.freshcaller.com"
    )
  end

  def freshcaller_account_publish_pattern fcaller_account
    {
      id: fcaller_account.id,
      freshdesk_account_id: fcaller_account.account_id,
      freshcaller_account_id: fcaller_account.freshcaller_account_id,
      freshcaller_domain: fcaller_account.domain,
      enabled: fcaller_account.enabled,
      settings: fcaller_account.settings_hash,
      created_at: fcaller_account.created_at.try(:utc).try(:iso8601),
      updated_at: fcaller_account.updated_at.try(:utc).try(:iso8601)
    }
  end

  def freshcaller_account_destroy_pattern fcaller_account
    {
      freshcaller_account_id: fcaller_account.freshcaller_account_id,
      freshdesk_account_id: fcaller_account.account_id
    }
  end
end