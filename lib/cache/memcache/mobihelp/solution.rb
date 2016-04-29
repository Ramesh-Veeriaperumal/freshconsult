module Cache::Memcache::Mobihelp::Solution
  
  include MemcacheKeys

  def clear_solutions_cache
    MemcacheKeys.delete_from_cache(mobihelp_solutions_key)
  end

  def clear_last_updated_time(app_id)
    MemcacheKeys.delete_from_cache(mobihelp_solution_updated_time_key(app_id))
  end

  def last_updated_time
    MemcacheKeys.fetch(mobihelp_solution_updated_time_key(id)) { 
      updated_time = self.app_solutions.find(:first, :select => :updated_at, :order => 'updated_at desc')
      updated_time.blank? ? nil : updated_time.updated_at 
    }
  end

  def solutions_with_category(category_ids)
    category_json_strings = []
    category_ids.each do |category_id|
      category_json_strings << solutions(category_id)
    end
    "[#{category_json_strings.join(",")}]"
  end

  def solutions_without_category(category_ids)
    category_json_strings = []
    category_ids.each do |category_id|
      category_hash = ActiveSupport::JSON.decode(solutions(category_id))
      category_hash["category"]["public_folders"].each do |f|
        category_json_strings << {"folder" => f}.to_json
      end
    end
    "[#{category_json_strings.join(",")}]"
  end

  def mobihelp_solutions_key
    MOBIHELP_SOLUTIONS % { :account_id => account_id, :category_id => self.id }
  end

  def mobihelp_solutions_key_with_category_id(category_id)
    MOBIHELP_SOLUTIONS % { :account_id => account_id, :category_id => category_id }
  end

  private

    def mobihelp_solution_updated_time_key(app_id)
      MOBIHELP_SOLUTION_UPDATED_TIME % { :account_id => account_id, :app_id => app_id }
    end
    
    def solutions(category_id)
      MemcacheKeys.fetch(mobihelp_solutions_key_with_category_id(category_id)) {
        category_meta = Solution::CategoryMeta.includes({:public_folder_meta => 
          {:published_article_meta => [:tags, :current_article_body]}}).find_by_id(category_id)

        category_meta.to_json(:include => {:public_folders => 
          {:include => {:published_articles => {:include => {:tags => {:only => :name }}, 
          :except => Solution::Article::API_OPTIONS[:except]}}, 
          :except => [:account_id, :import_id]}})
      }
    end

end
