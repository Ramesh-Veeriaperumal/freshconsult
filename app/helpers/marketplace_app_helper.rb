module MarketplaceAppHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Marketplace::GalleryConstants

  def marketplace_ni_extension_details(account_id, extension_name)
    get_others_redis_hash(marketplace_cache_key(account_id, extension_name))
  end

  def set_or_add_marketplace_ni_extension_details(account_id, extension_name, installed_extension_id)
    set_others_redis_hash_set(marketplace_cache_key(account_id, extension_name), :installed_extension_id, installed_extension_id)
  end

  def set_marketplace_ni_extension_details(account_id, extension_name, addon_id, install_type)
    marketplace_key = marketplace_cache_key(account_id, extension_name)
    set_others_redis_hash(marketplace_key, addon_id: addon_id, install_type: install_type)
    set_others_redis_expiry(marketplace_key, MARETPLACE_PAID_NI_APPS_EXPIRY)
  end

  private

    def marketplace_cache_key(account_id, extension_name)
      format(
        MARKETPLACE_NI_PAID_APP,
        account_id: account_id,
        app_name: extension_name
      )
    end
end
