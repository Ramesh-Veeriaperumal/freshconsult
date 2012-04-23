class Support::SupportController < ApplicationController
  layout 'portal'
  protected
  	def set_layout
  		render "/portal/layout"
  		#@portal_layout = current_portal.layout
  		#!@portal_layout.blank? ? @portal_layout || 'portal'
  	end
end