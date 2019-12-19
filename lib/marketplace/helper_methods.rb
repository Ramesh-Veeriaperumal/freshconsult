module Marketplace::HelperMethods

  OAUTH_IPARAM_FEATURE = 'oauth_iparams'

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

  def extension_v2
    extension = extension_details_v2(params[:extension_id], params[:version_id])
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
    # TODO: app_type should be removed after new ext type is added for custom app
    @extension['app_type'] == Marketplace::Constants::APP_TYPE[:custom] || 
    @extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:custom_app]
  end

  def paid_app?
    @extension['addons']
  end
  
  def is_oauth_app?(extension)
    extension["features"].present? and extension['features'].include?('oauth')
  end

  def has_oauth_iparams?(extn=nil)
    extension = extn || @extension
    extension["features"].present? and extension['features'].include?(OAUTH_IPARAM_FEATURE)
  end

  def addon_details
    @addon_details ||= @extension['addons'].find { |data| data['currency_code'] == Account.current.currency_name }
  end

  def paid_app_params
    paid_app? ? {
      :billing => {
        :addon_id => addon_details['addon_id']
      }.merge(account_params)
    } : {}
  end

  def per_agent_plan?
    addon_details['addon_type'] == Marketplace::Constants::ADDON_TYPES[:agent]
  end

  def addon_type
    per_agent_plan? ? t('marketplace.agent') : t('marketplace.account')
  end

  def app_units_count
    if trial_subscription?
      # Agent limit is set to 1 as it is null for trial accounts
      return Marketplace::Constants::ACCOUNT_ADDON_APP_UNITS
    end
    if per_agent_plan?
      return Account.current.subscription.new_sprout? ? 
             Account.current.full_time_support_agents.count : Account.current.subscription.agent_limit
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

  def skip_validation?
    trial_subscription? || offline_subscription_and_addon_added?
  end

  def account_subscription_verify?
    paid_app? && !skip_validation?
  end

  def trial_subscription?
    Account.current.subscription.trial?
  end

  def offline_subscription_and_addon_added?
    offline_subscription? && addon_added_to_subscription?
  end

  def offline_subscription?
    Account.current.subscription.offline_subscription?
  end

  def addon_added_to_subscription?
    subscription_mkp_addons = Billing::Subscription.new.retrieve_subscription(Account.current.id).subscription.addons
    subscription_mkp_addons.present? ? subscription_mkp_addons.map(&:id).include?(addon_details['addon_id']) : false
  end
    
end
