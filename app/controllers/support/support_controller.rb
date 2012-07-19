class Support::SupportController < ApplicationController
  layout 'portal'
  before_filter :set_portal
  before_filter :set_liquid_variables

  private
  	def set_portal
  		@portal ||= current_portal
  	end

  	def set_liquid_variables
  		@header_content ||= get_default_header
  		@portal_layout  ||= get_default_layout
  		@footer_content ||= get_default_footer 
  		@search_portal = render_to_string :partial => "/search/pagesearch", :locals => { :placeholder => t('portal.search.placeholder') }
  	end

  	def get_default_header
  		render_to_string :partial => "portal/header"
  	end

  	def get_default_layout
		render_to_string :partial => "portal/layout"
  	end

  	def get_default_footer
  		render_to_string :partial => "portal/footer"
  	end
end