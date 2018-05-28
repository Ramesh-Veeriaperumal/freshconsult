module Cache::Memcache::Dashboard::Custom::CacheData
  include Cache::Memcache::Dashboard::Custom::MemcacheKeys
  include Dashboard::Custom::CustomDashboardConstants

  # Has to be handled if single instance modules are introduced
  WIDGET_MODULE_NAMES.each do |module_name|
    define_method "#{module_name}_key" do
      Cache::Memcache::Dashboard::Custom::MemcacheKeys.const_get("CUSTOM_DASHBOARD_#{module_name.upcase}S") % { account_id: Account.current.id, dashboard_id: self.id }
    end

    define_method "#{module_name}_widgets_from_cache" do
      MemcacheKeys.fetch(send("#{module_name}_key")) { self.widgets.send("#{module_name}s").all }
    end

    define_method "#{module_name}_cache_key" do |dashboard_id|
      Cache::Memcache::Dashboard::Custom::MemcacheKeys.const_get("CUSTOM_DASHBOARD_#{module_name.upcase}_DATA") % { account_id: Account.current.id, dashboard_id: dashboard_id }
    end
  end

  # def dashboard_widgets_from_cache
  #   MemcacheKeys.fetch(custom_dashboard_widgets_key) { self.widgets.all_active.all }
  # end

  def clear_custom_dashboard_widgets_cache
    keys = WIDGET_MODULE_NAMES.map { |module_name| [safe_send("#{module_name}_key"), safe_send("#{module_name}_cache_key", self.id), dashboard_cache_key(self.id)] }.flatten
    keys.each { |key| MemcacheKeys.delete_from_cache(key) }
  end

  # def custom_dashboard_widgets_key
  #   CUSTOM_DASHBOARD_WIDGETS % { account_id: Account.current.id, dashboard_id: self.id }
  # end

end
