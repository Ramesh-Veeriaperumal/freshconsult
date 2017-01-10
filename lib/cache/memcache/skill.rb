module Cache::Memcache::Skill

  include MemcacheKeys

  def clear_skills_cache
    key = ACCOUNT_SKILLS_TRIMMED % { :account_id => self.account_id }
    MemcacheKeys.delete_from_cache key

    key = ACCOUNT_SKILLS % { :account_id => self.account_id }
    MemcacheKeys.delete_from_cache key
  end

end
