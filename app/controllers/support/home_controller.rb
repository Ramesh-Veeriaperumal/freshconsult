class Support::HomeController < SupportController

  def index
    flash.keep(:notice)
  	redirect_to support_login_path and return unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))
  	
  	# Adding a redirect_to_login for product portals if it is not having any top level solution or folder category
  	if !current_portal.main_portal
  		redirect_to support_login_path and return if 
  			(current_portal.solution_categories.blank? && current_portal.forum_categories.blank?)
  	end

    set_portal_page :portal_home
  end

end