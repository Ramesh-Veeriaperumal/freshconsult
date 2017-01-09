module Admin::DkimConfigurationsHelper

  def dkim_configured?(domain_category)
    domain_category.dkim_records.present?
  end

  def fetch_customer_settings(domain_category)
    domain_category.dkim_records.filter_customer_records
  end
  
end