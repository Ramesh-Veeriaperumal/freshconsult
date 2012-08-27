class SupportController < ApplicationController
  layout 'portal'
  before_filter :set_portal
  before_filter :set_liquid_variables  

  def new
     @user_session = current_account.user_sessions.new   
     @login_form = render_to_string :partial => "login"
  end

  def set_portal_page( page_type_token )
    # @dynamic_template = current_portal.template.pages.find_by_page_type( Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_type_token ] ).content 
    @dynamic_page = current_portal.template.pages.find_by_page_type( Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_type_token ] )
    @dynamic_template = @dynamic_page.content unless @dynamic_page.blank?
  end

  private
  	def set_portal
  		@portal ||= current_portal
  	end

  	def set_liquid_variables
  		@header_content ||= render_to_string :partial => "portal/header", :locals => { :dynamic_template => current_portal.template.header }
  		@footer_content ||= render_to_string :partial => "portal/footer", :locals => { :dynamic_template => current_portal.template.footer }
      @contact_us     ||= render_to_string :partial => "portal/contact_info", :locals => { :dynamic_template => current_portal.template.contact_info }
  		@search_portal  ||= render_to_string :partial => "/search/pagesearch", :locals => { :placeholder => t('portal.search.placeholder') }
  	end


end