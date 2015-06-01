module Cache::Memcache::Mobihelp::Solution
  
  include MemcacheKeys

  def clear_solutions_cache(category_id)
    MemcacheKeys.delete_from_cache(mobihelp_solutions_key(category_id))
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

  def solutions_with_category(categories)
    category_json_strings = []
    categories.each do |category|
      category_json_strings << solutions(category)
    end
    "[#{category_json_strings.join(",")}]"
  end

  def solutions_without_category(categories)
    category_json_strings = []
    categories.each do |category|
      category_hash = ActiveSupport::JSON.decode(solutions(category))
      category_hash["category"]["public_folders"].each do |f|
        category_json_strings << {"folder" => f}.to_json
      end
    end
    "[#{category_json_strings.join(",")}]"
  end

  private
    def mobihelp_solutions_key(category_id)
      MOBIHELP_SOLUTIONS % { :account_id => account_id, :category_id => category_id }
    end

    def mobihelp_solution_updated_time_key(app_id)
      MOBIHELP_SOLUTION_UPDATED_TIME % { :account_id => account_id, :app_id => app_id }
    end

    def solutions(category)
      MemcacheKeys.fetch(mobihelp_solutions_key(category.id)) { 
        category.to_json(:except => :account_id, :include => {:public_folders => {:include => :published_articles}} )
      }
    end

end
