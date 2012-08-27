class HomeController < SupportController
	
 	before_filter { @hash_of_additional_params = { :format => "html" } }  
 	before_filter :set_portal_variables
  before_filter :set_content_scope, :set_mobile
  before_filter :only => :index do |c|
    c.send(:set_portal_page, :portal_home)
  end
  
  def index
    redirect_to MOBILE_URL and return if (current_user && mobile?)
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    redirect_to login_path unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))
    
    #@categories = current_portal.solution_categories.customer_categories if allowed_in_portal?(:open_solutions)
    if allowed_in_portal?(:open_solutions)
      @categories = main_portal? ? current_portal.solution_categories.customer_categories : current_portal.solution_categories
    end

    if params[:format] == "mobile"
      @user_session = current_account.user_sessions.new
    end
    
    @topics = recent_topics if allowed_in_portal?(:open_forums)
  end

  def liquid_list
    
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
    
    def set_portal_variables
      @portal_template = current_portal.template
    end                     
    
end
