module Admin::DkimConfigurationsHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

  DISABLE_BUTTON = "disabled"
  MANUALLY_CONFIGURED_DOMAIN_CATEGORY = 5

  def dkim_configured?(domain_category)
    domain_category.dkim_records.present?
  end

  def fetch_customer_settings(domain_category)
    domain_category.dkim_records.filter_customer_records
  end

  def dkim_limit_exceeded?(email_domain)
    return if manually_configured_domain?(email_domain)

    return if current_account.advanced_dkim_enabled? and current_account.subscription.state != "trial"
    
    return if @dkim_count.to_i < OutgoingEmailDomainCategory::MAX_DKIM_ALLOWED and current_account.basic_dkim_enabled?
    DISABLE_BUTTON
  end

  def es_dkim_configured?(dkim_records, domain)
    dkim_records.nil? ? false : dkim_records[domain.to_sym].present?
  end

  def manually_configured_domain?(domain)
    ismember?(
      format(
        MIGRATE_MANUALLY_CONFIGURED_DOMAINS,
        account_id: current_account.id
      ),
      domain.email_domain
    ) && domain.category == MANUALLY_CONFIGURED_DOMAIN_CATEGORY
  end
end
