module Cache::Memcache::Survey
  
  include MemcacheKeys

  def clear_custom_survey_cache
    key = ACCOUNT_CUSTOM_SURVEY % {:account_id => self.account_id}
    MemcacheKeys.delete_from_cache key
  end

  def active_survey_updated?
    active? || just_disabled?
  end
  
  def just_disabled?
    previous_changes[:active] == [1, 0]
  end

end