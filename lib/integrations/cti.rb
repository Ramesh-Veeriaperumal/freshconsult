class Integrations::Cti

  def clear_memcache(inst_app)
    inst_app.account.clear_cti_installed_app_from_cache
  end

end