module TrialWidgetTestHelper
  def old_trial_widget_index_pattern
    {
      tasks: Account.current.current_setup_keys.map { |setup_key| setup_key_info(setup_key) }
    }
  end

  def new_trial_widget_index_pattern
    {
      tasks: Account.current.setup_keys.map { |setup_key| setup_key_info(setup_key) },
      goals: Account.current.account_additional_settings_from_cache.additional_settings[:onboarding_goals]
    }
  end


  def trial_widget_sales_manager_pattern
    {
      name: Account.current.fresh_sales_manager_from_cache.try(:[], :display_name)
    }
  end

  def setup_key_info(setup_key)
    {
      name: setup_key,
      isComplete: Account.current.send("#{setup_key}_setup?")
    }
  end

  def support_email_dependent_info
    { email_service_provider: Account.current.account_configuration.company_info[:email_service_provider] }
  end

  def setup_key_info(setup_key)
    dependent_fname = "#{setup_key}_dependent_info"
    {
      name: setup_key,
      isComplete: Account.current.send("#{setup_key}_setup?")
    }.merge(respond_to?(dependent_fname, 'private') ? send(dependent_fname) : {})
  end

end
