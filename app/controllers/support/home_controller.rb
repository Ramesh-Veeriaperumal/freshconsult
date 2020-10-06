class Support::HomeController < SupportController
  before_filter :redirect_to_support_home, if: :facebook?
  before_filter :load_page_meta, :unless => :facebook?
  
  def index
    flash.keep(:notice)
  	redirect_to support_login_path and return unless (allowed_in_portal?(:open_solutions) || forums_enabled?)
  	
  	# Adding a redirect_to_login for product portals if it is not having any top level solution or folder category
  	if !current_portal.main_portal and !facebook?
  		redirect_to current_user ? support_tickets_path : support_login_path and return if 
  			(current_portal.solution_category_meta.blank? && current_portal.forum_categories.blank?)
  	end

    set_portal_page facebook? ? :facebook_home : :portal_home
  end

  def redirect_to_support_home
    redirect_to '/support/home'
  end

  private

    def load_page_meta
      portal_drop = current_portal.to_liquid
      return unless portal_drop.has_solutions ^ portal_drop.has_forums
      @page_canonical = portal_drop.has_solutions ? 
                          support_solutions_url(:host => current_portal.host, :protocol => current_account.url_protocol) : 
                          support_discussions_url(:host => current_portal.host, :protocol => current_account.url_protocol)
    end
end