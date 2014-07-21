module Cache::Memcache::Mobihelp::Solution
  
  include MemcacheKeys

  def clear_solutions_cache(category_id)
    MemcacheKeys.delete_from_cache(MOBIHELP_SOLUTIONS % { :account_id => self.account_id, :category_id => category_id })
    MemcacheKeys.delete_from_cache(MOBIHELP_SOLUTION_UPDATED_TIME % { :account_id => self.account_id, 
        :category_id => category_id })
  end

  def fetch_recently_updated_time(category_id)
    account_id = self.account_id
    app_id = self.id
    key = MOBIHELP_SOLUTION_UPDATED_TIME % { :account_id => account_id, :category_id => category_id }

    MemcacheKeys.fetch(key) { 
      result = ActiveRecord::Base.connection.execute(%(SELECT MAX(updated_at) AS RECENTLY_UPDATED_TIME FROM (
          (SELECT `updated_at` FROM solution_folders 
            WHERE `account_id` = #{account_id} AND `category_id` = #{category_id} AND `is_default` = 0 AND 
              `visibility` = #{Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]}) 
          UNION 
          (SELECT a.`updated_at` FROM solution_folders f JOIN solution_articles a 
            ON f.`Id` = a.`folder_id` 
            WHERE a.`status` = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]} AND 
              a.`account_id` = #{account_id} AND f.`account_id` = #{account_id} AND
              f.`category_id` = #{category_id} AND f.`is_default` = 0 AND 
              f.`visibility` = #{Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]} )
          UNION
          (SELECT `updated_at` FROM `mobihelp_apps` WHERE account_id = #{account_id} AND id = #{app_id})) 
        AS UPDATED_TIME))
      result_hash = result.fetch_hash
      result_hash["RECENTLY_UPDATED_TIME"]
    }
  end

  def fetch_solutions(category)
    key = MOBIHELP_SOLUTIONS % { :account_id => self.account_id, :category_id => category.id }
    MemcacheKeys.fetch(key) { 
      folder_json_strings = []
      category.public_folders.each do |folder|
        folder_json_strings << folder.to_json(:include=>:published_articles) unless folder.published_articles.blank?
      end
      solution_data = "[#{folder_json_strings.join(",")}]"
      solution_data 
    }
  end

end
