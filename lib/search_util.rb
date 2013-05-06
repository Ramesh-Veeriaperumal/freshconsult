module SearchUtil

	DEFAULT_SEARCH_VALUE = "1"
	
	RESTRICTED_CLASSES = [ User, Customer ] 
	def forum_visibility
      vis_arr = Array.new
      if current_user
        if current_user.agent?
          vis_arr = Forum::VISIBILITY_NAMES_BY_KEY.keys
        else
          vis_arr = [Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone],Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
          vis_arr.push(Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]) if (current_user && current_user.has_company?)
        end
      else
        vis_arr = [Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]]   
      end
      vis_arr
    end

  def solution_visibility
  	if current_user
  		if current_user.agent?
  			Solution::Folder::VISIBILITY_NAMES_BY_KEY.keys
  		else
  			contact_solution_visibility
  		end
  	else
  		[ Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ]
  	end
  end

  def self.es_filter_key(query)
    query.strip!
    query.gsub!(/([\(\)\[\]\{\}\?\\\"!\^\+\-\*:~])/,'\\\\\1')
    query = "*#{query}*"
  end

  def self.es_exact_match?(query)
    query.blank? || ( query.start_with?('<') && query.end_with?('>') )
  end

  def self.es_filter_exact(query)
    query = "#{query.gsub(/^<|>$/,'').strip}" unless query.blank?
    query
  end

  private

  	def contact_solution_visibility
  	  to_ret = [ Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone], 
  	  	Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users] ]
    	to_ret.push(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]) if current_user.has_company?

    	to_ret
  	end

end