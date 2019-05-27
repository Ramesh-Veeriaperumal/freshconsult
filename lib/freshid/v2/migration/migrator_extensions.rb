module Freshid::V2::Migration::MigratorExtensions
  def fetch_sandbox_account(account)
    sandbox_domain = account.sandbox_domain
    if sandbox_domain.present?
      sandbox_account_id = account.sandbox_job.try(:sandbox_account_id)
      [{ 'domain' => sandbox_domain,
        'external_id' => sandbox_account_id.to_s,
        'product_id' => FRESHID_V2_PRODUCT_ID.to_s }]
    end
  end

  def fetch_freshconnect_accounts(account, linked_accounts)
    product_id = product_account_mapping[@freshconnect_product_name]
    freshconnect_account = account.freshconnect_account
    return if product_id.blank? || freshconnect_account.blank?
    account_info = {}
    unless linked_account_present?(linked_accounts, product_id, freshconnect_account.freshconnect_domain)
      account_info[:domain] = freshconnect_account.freshconnect_domain
      account_info[:external_id] = freshconnect_account.product_account_id
      account_info[:product_id] = product_id
    end
    [account_info]
  end

  def fetch_freshcaller_accounts(account, linked_accounts)
    product_id = product_account_mapping[@freshcaller_product_name]
    freshcaller_account = account.freshcaller_account
    return if product_id.blank? || freshcaller_account.blank?
    account_info = {}
    unless linked_account_present?(linked_accounts, product_id, freshcaller_account.domain)
      account_info[:domain] = freshcaller_account.domain
      account_info[:external_id] = freshcaller_account.freshcaller_account_id
      account_info[:product_id] = product_id
    end
    [account_info]
  end

  def account_admin_emails(account)
    email = account.admin_email || account.account_managers.first.try(:email)
    email.to_a
  end

end
