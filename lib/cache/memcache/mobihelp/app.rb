module Cache::Memcache::Mobihelp::App
  
  include MemcacheKeys

  def clear_app_cache
    MemcacheKeys.delete_from_cache(MOBIHELP_APP % {:account_id => self.account_id, 
      :app_key => self.app_key, :app_secret => self.app_secret})
  end

  def fetch_app_from_cache(account, app_key)
    key = MOBIHELP_APP % { :account_id => account.id, :app_key => app_key }
    MemcacheKeys.fetch(key) { account.mobihelp_apps.find_by_app_key(app_key) }
  end
  
  def app_solution_category_ids
    key = MOBIHELP_SOLUTION_CATEGORY_IDS % { :account_id => self.account_id, :app_key => self.app_key }
    MemcacheKeys.fetch(key) { 
      category_ids = []
      self.solution_categories.each do |category| 
        category_ids << category.id
      end
      category_ids
    }
  end
  
  def clear_app_solution_category_ids
    key = MOBIHELP_SOLUTION_CATEGORY_IDS % { :account_id => self.account_id, :app_key => self.app_key }
    MemcacheKeys.delete_from_cache(key)
  end
end
