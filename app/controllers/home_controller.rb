class HomeController < ApplicationController
  def index
    redirect_to (current_user && current_user.permission?(:manage_tickets)) ? helpdesk_dashboard_path : support_guides_path
  end
end
