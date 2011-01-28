class HomeController < ApplicationController
  def index
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    
    @folder = Solution::Folder
  end
end
