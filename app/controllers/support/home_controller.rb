class Support::HomeController < SupportController

  def index
    flash.keep(:notice)
  	redirect_to support_login_path and return unless (allowed_in_portal?(:open_solutions) || forums_enabled?)
  	
  	# Adding a redirect_to_login for product portals if it is not having any top level solution or folder category
  	if !current_portal.main_portal and !facebook?
  		redirect_to current_user ? support_tickets_path : support_login_path and return if 
  			(current_portal.solution_categories.blank? && current_portal.forum_categories.blank?)
  	end

    set_portal_page facebook? ? :facebook_home : :portal_home
  end

end