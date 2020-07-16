module Cache::Memcache::Dashboard::Custom::CacheData
  include Cache::Memcache::Dashboard::Custom::MemcacheKeys
  include Dashboard::Custom::CustomDashboardConstants

  # Has to be handled if single instance modules are introduced
  WIDGET_MODULE_NAMES.each do |module_name|
    define_method "#{module_name}_key" do |dashboard_id = id|
      Cache::Memcache::Dashboard::Custom::MemcacheKeys.const_get("CUSTOM_DASHBOARD_#{module_name.upcase}S") % { account_id: Account.current.id, dashboard_id: dashboard_id }
    end

    define_method "#{module_name}_widgets_from_cache" do
      MemcacheKeys.fetch(send("#{module_name}_key")) { self.widgets.send("#{module_name}s").all }
    end

    define_method "#{module_name}_cache_key" do |dashboard_id|
      Cache::Memcache::Dashboard::Custom::MemcacheKeys.const_get("CUSTOM_DASHBOARD_#{module_name.upcase}_DATA") % { account_id: Account.current.id, dashboard_id: dashboard_id }
    end
  end

  def dashboard_cache_key(dashboard_id)
    CUSTOM_DASHBOARD % { account_id: Account.current.id, dashboard_id: dashboard_id }
  end

  # def dashboard_widgets_from_cache
  #   MemcacheKeys.fetch(custom_dashboard_widgets_key) { self.widgets.all_active.all }
  # end

  def dashboard_filters_key(dashboard_id = id)
    CUSTOM_DASHBOARD_TICKET_FILTERS % { account_id: Account.current.id, dashboard_id: dashboard_id }
  end

  def dashboard_filters_from_cache(dashboard_id)
    dashboard = Account.current.dashboards.find(dashboard_id)
    # 0 - scorecard 1 - bar_chart
    MemcacheKeys.fetch(dashboard_filters_key(dashboard_id)) do
      filter_ids = dashboard.widgets.where('widget_type IN (?)', [0, 1]).pluck(:ticket_filter_id).compact.uniq
      Account.current.ticket_filters.where(id: filter_ids).to_a
    end
  end

  # def custom_dashboard_widgets_key
  #   CUSTOM_DASHBOARD_WIDGETS % { account_id: Account.current.id, dashboard_id: self.id }
  # end

  def clear_custom_dashboard_widgets_cache
    keys = fetch_module_keys(WIDGET_MODULE_NAMES, id) + [dashboard_filters_key(id)]
    delete_multiple_from_cache(keys)
  end

  def clear_group_widgets_from_cache(dashboard_id)
    keys = fetch_module_keys(GROUP_WIDGETS, dashboard_id)
    delete_multiple_from_cache(keys)
  end

  def clear_product_widgets_from_cache(dashboard_id)
    keys = fetch_module_keys(PRODUCT_WIDGETS, dashboard_id)
    delete_multiple_from_cache(keys)
  end

  def clear_ticket_filter_widgets_from_cache(dashboard_id)
    keys = fetch_module_keys(TICKET_FILTER_WIDGETS, dashboard_id) + [dashboard_filters_key(dashboard_id)]
    delete_multiple_from_cache(keys)
  end

  def delete_multiple_from_cache(keys)
    keys.each { |key| MemcacheKeys.delete_from_cache(key) }
  end

  def fetch_module_keys(module_list, dashboard_id)
    [dashboard_cache_key(dashboard_id), module_list.map { |w| [safe_send("#{w}_key", dashboard_id), safe_send("#{w}_cache_key", dashboard_id)] }].flatten
  end
end
