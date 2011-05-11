class HomeController < ApplicationController
  def index
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    redirect_to login_path unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))
    
    @categories = current_account.solution_categories if allowed_in_portal?(:open_solutions)
    @topics = Topic.find(:all,:conditions => ["account_id = ?", current_account.id], 
              :order => "replied_at desc", :limit =>5 ) if allowed_in_portal?(:open_forums)
  end
  
end
