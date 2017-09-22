module TrialWidgetTestHelper
  def trial_widget_index_pattern
    {
      tasks: Account.current.current_setup_keys.map { |setup_key| setup_key_info(setup_key) }
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
end
