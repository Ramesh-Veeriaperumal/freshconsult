class Support::HomeController < SupportController

  def index
  	redirect_to support_login_path and return unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))
  	
    set_portal_page :portal_home
  end

end