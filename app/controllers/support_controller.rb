class SupportController < ApplicationController

  layout 'portal'
  before_filter :set_portal, :set_forum_builder

  def new
    @user_session = current_account.user_sessions.new
    set_portal_page :user_login
  end
 
  protected
    def set_portal_page(page_label)
      set_layout_liquid_variables page_label
      # Setting up current_tab based on the page type obtained
      set_tab page_label

      # Setting dynamic header, footer, layout and misc. information 
      set_common_liquid_variables    
    end

  private
  	def set_portal
  		@portal ||= current_portal
  	end

    def preview?
      !session[:preview_button].blank? && !current_user.blank? && current_user.agent?
    end

    def set_tab token    
      if [ :portal_home ].include?(token)
        @current_tab = "home"
      elsif [ :discussions_home, :topic_list, :topic_view, :new_topic ].include?(token)
        @current_tab = "forums"
      elsif [ :solution_home, :article_list, :article_view ].include?(token)
        @current_tab = "solutions"
      elsif [ :ticket_list, :ticket_view ].include?(token)
        @current_tab = "tickets"
      elsif [ :company_ticket_list ].include?(token)
        @current_tab = "company_tickets"
      end
    end

  	def set_common_liquid_variables
      Portal::Template::TEMPLATE_MAPPING.each_with_index do |t, t_i|
          _content = render_to_string :partial => t[1], 
                      :locals => { :dynamic_template => (get_data_for_template(t[0]) || "") }
          instance_variable_set "@#{t[0]}", _content
      end
  	end

    def set_layout_liquid_variables(page_label)
      partial = Portal::Page::PAGE_FILE_BY_TOKEN[ page_label ]
      _content = render_to_string :file => partial,
                  :locals => { :dynamic_template => (get_data_for_page(page_label) || "") }
      @content_for_layout = _content
    end

    def get_data_for_template(sym)
      data = current_portal.template[sym] 
      data = current_portal.template.get_draft[sym] || current_portal.template[sym] if preview?
      data
    end

    def get_data_for_page(page_label)
      page_type = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_label ]
      page = current_portal.template.pages.find_by_page_type( page_type )
      page_template = page.content unless page.blank?
      if preview?
        draft_page = current_portal.template.page_from_cache(page_label)
        page_template = draft_page[:content] unless draft_page.nil?
      end
      page_template
    end

    def set_forum_builder
      ActionView::Base.default_form_builder = FormBuilders::RedactorBuilder
    end

end