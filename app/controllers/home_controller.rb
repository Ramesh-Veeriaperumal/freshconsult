class HomeController < ApplicationController

  before_filter :redirect_to_mobile_url
  skip_before_filter :check_privilege, :verify_authenticity_token	
 	before_filter { @hash_of_additional_params = { :format => "html" } }
  before_filter :set_content_scope, :set_mobile
  
  def index
    # redirect_to MOBILE_URL and return if (current_user && mobile?)
    if (current_user && privilege?(:manage_tickets))
      redirect_to helpdesk_dashboard_path and return
    else
      flash.keep(:notice)
      redirect_to '/support/home' and return
    end   
    # redirect_to login_path and return unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))
    
    # @categories = current_portal.solution_categories.customer_categories if allowed_in_portal?(:open_solutions)
    # if allowed_in_portal?(:open_solutions)
    #   @categories = main_portal? ? current_portal.solution_categories.customer_categories : current_portal.solution_categories
    # end

    # if params[:format] == "mob"
    #   @user_session = current_account.user_sessions.new
    #   redirect_to login_path
    # end
    
  end
 
  protected
  
    def set_content_scope
      @content_scope = 'portal_'
      @content_scope = 'user_'  if privilege?(:view_forums)
    end

end
