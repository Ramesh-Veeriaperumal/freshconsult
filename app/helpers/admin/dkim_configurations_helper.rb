module Admin::DkimConfigurationsHelper
  
  DISABLE_BUTTON = "disabled"

  def dkim_configured?(domain_category)
    domain_category.dkim_records.present?
  end

  def fetch_customer_settings(domain_category)
    domain_category.dkim_records.filter_customer_records
  end

  def dkim_limit_exceeded?
    return if current_account.advanced_dkim_enabled? and current_account.subscription.state != "trial"
    
    return if @dkim_count.to_i < OutgoingEmailDomainCategory::MAX_DKIM_ALLOWED and current_account.basic_dkim_enabled?
    DISABLE_BUTTON
  end

  def es_dkim_configured?(dkim_records, domain)
    dkim_records.nil? ? false : dkim_records[domain.to_sym].present?
  end
end
