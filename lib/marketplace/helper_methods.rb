module Marketplace::HelperMethods

  private

  def categories
    categories = all_categories
    render_error_response and return if error_status?(categories)
    @categories = categories.body
  end

  def extension
    extension = extension_details
    render_error_response and return if error_status?(extension)
    @extension = extension.body
  end

  def is_ni?
    @extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:ni]
  end

  def is_versionable?
    is_plug?
  end

  def is_non_versionable?
    is_ni? || is_external_app?
  end

  def is_plug?
    @extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:plug]
  end

  def is_external_app?
    @extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:external_app]
  end

  def custom_app?
    @extension['app_type'] == Marketplace::Constants::APP_TYPE[:custom]
  end

  def paid_app?
    @extension['addon']
  end

  def addon_details
    @addon_details ||= @extension['addon']['metadata'].find { |data| data['currency_code'] == Account.current.currency_name }
  end

  def paid_app_params
    paid_app? ? {
      :billing => {
        :addon_id => @extension['addon']['id']  
      }.merge(account_params)
    } : {}
  end

  def per_agent_plan?
    @extension['addon']['addon_type'] == Marketplace::Constants::ADDON_TYPES[:agent]
  end

  def addon_type
   per_agent_plan? ? t('marketplace.agent') : t('marketplace.account')
  end

  def app_units_count
    if per_agent_plan?
      return Account.current.subscription.new_sprout? ? 
             Account.current.full_time_agents.count : Account.current.subscription.agent_limit
    else
      return Marketplace::Constants::ACCOUNT_ADDON_APP_UNITS
    end
  end

  def account_params
    {
      :product =>  Marketplace::Constants::PRODUCT_NAME,
      :currency_code => Account.current.currency_name,
      :agent_count => app_units_count,
      :renewal_period => Account.current.subscription.renewal_period
    }
  end
    
end
