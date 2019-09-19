module Cache::Memcache::Product

  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(format(ACCOUNT_PRODUCTS, account_id: account_id))
    MemcacheKeys.delete_from_cache(format(ACCOUNT_PRODUCTS_OPTAR, account_id: account_id))
  end
end
