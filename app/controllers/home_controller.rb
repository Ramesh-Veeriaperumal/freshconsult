class HomeController < ApplicationController
  
  before_filter :set_content_scope
  
  def index
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    redirect_to login_path unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))
    
    @categories = current_portal.solution_categories if allowed_in_portal?(:open_solutions)
    
    @topics = recent_topics if allowed_in_portal?(:open_forums)
  end
 
  protected
  
    def set_content_scope
      @content_scope = 'portal_'
      @content_scope = 'user_'  if permission?(:post_in_forums) 
    end
  
    def recent_topics
      current_portal.main_portal? ? current_account.send("#{@content_scope}topics").newest(5) : 
        (current_portal.forum_category ? 
            current_portal.forum_category.send("#{@content_scope}topics").newest(5) : [])
    end
  
end
