module Cache::Memcache::OrganisationAccountMapping
  include MemcacheKeys

  def clear_cache_by_account_id
    key = format(ORGANISATION_BY_ACCOUNT_ID, account_id: self.account_id)
    MemcacheKeys.delete_from_cache key
  end

  def clear_account_ids_by_organisation_cache(organisation_id)
    key = format(MemcacheKeys::ACCOUNT_ID_BY_ORGANISATION, organisation_id: organisation_id)
    MemcacheKeys.delete_from_cache key
  end
end
