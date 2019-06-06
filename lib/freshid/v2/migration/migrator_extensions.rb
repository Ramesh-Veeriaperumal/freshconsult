module Freshid::V2::Migration::MigratorExtensions

  def fetch_freshconnect_accounts(account, linked_accounts)
    product_id = product_account_mapping[@freshconnect_product_name].try(:to_s)
    freshconnect_account = account.freshconnect_account
    return if product_id.blank? || freshconnect_account.blank?
    account_info = {}
    unless linked_account_present?(linked_accounts, product_id, freshconnect_account.freshconnect_domain)
      account_info[:domain] = freshconnect_account.freshconnect_domain
      account_info[:external_id] = freshconnect_account.product_account_id.to_s
      account_info[:product_id] = product_id
    end
    account_info.present? ? [account_info] : nil
  end

  def fetch_freshcaller_accounts(account, linked_accounts)
    product_id = product_account_mapping[@freshcaller_product_name].try(:to_s)
    freshcaller_account = account.freshcaller_account
    return if product_id.blank? || freshcaller_account.blank?
    account_info = {}
    unless linked_account_present?(linked_accounts, product_id, freshcaller_account.domain)
      account_info[:domain] = freshcaller_account.domain
      account_info[:external_id] = freshcaller_account.freshcaller_account_id.to_s
      account_info[:product_id] = product_id
    end
    account_info.present? ? [account_info] : nil
  end

  def account_admin_emails(account)
    email = account.admin_email || account.account_managers.first.try(:email)
    email.to_a
  end

end
