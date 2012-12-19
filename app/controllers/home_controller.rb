class HomeController < ApplicationController
  before_filter :set_content_scope, :set_mobile, :set_selected_tab
  
  def index
    redirect_to MOBILE_URL and return if (current_user && mobile?)
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    redirect_to login_path and return unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))
    
    #@categories = current_portal.solution_categories.customer_categories if allowed_in_portal?(:open_solutions)
    if allowed_in_portal?(:open_solutions)
      @categories = main_portal? ? current_portal.solution_categories.customer_categories : current_portal.solution_categories
    end

    if params[:format] == "mob"
      @user_session = current_account.user_sessions.new
      redirect_to login_path
    end
    
    @topics = recent_topics if allowed_in_portal?(:open_forums)
  end
 
  protected
  
    def set_content_scope
      @content_scope = 'portal_'
      @content_scope = 'user_'  if permission?(:post_in_forums) 
    end
  
    def recent_topics
      current_portal.main_portal? ? current_account.topics.visible(current_user).newest(5) : 
        (current_portal.forum_category ? 
            current_portal.forum_category.topics.visible(current_user).newest(5) : [])
    end
  private
    def set_selected_tab
      @selected_tab = :home
    end
  
end
