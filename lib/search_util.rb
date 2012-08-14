module SearchUtil

	DEFAULT_SEARCH_VALUE = "1"
	
	RESTRICTED_CLASSES = [ User, Customer ] 

	def forum_visibility
      vis_arr = Array.new
      if permission?(:manage_forums)
        vis_arr = Forum::VISIBILITY_NAMES_BY_KEY.keys
      elsif permission?(:post_in_forums)
        vis_arr = [Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone],Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
        vis_arr.push(Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]) if (current_user && current_user.has_company?)
      else
        vis_arr = [Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]]   
      end
    end

  def solution_visibility
  	if current_user
  		if current_user.has_manage_solutions?
  			Solution::Folder::VISIBILITY_NAMES_BY_KEY.keys
  		else
  			contact_solution_visibility
  		end
  	else
  		[ Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ]
  	end
  end

  private

  	def contact_solution_visibility
  	  to_ret = [ Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone], 
  	  	Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users] ]
    	to_ret.push(Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]) if current_user.has_company?

    	to_ret
  	end

end