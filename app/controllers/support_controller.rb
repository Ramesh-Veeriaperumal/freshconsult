class SupportController < ApplicationController
  include RedisKeys

  layout 'portal'
  before_filter :set_portal, :set_forum_builder

  def new    
    @user_session = current_account.user_sessions.new
    set_portal_page :user_login
  end
 
  protected
    def set_portal_page(page_type_token)
      set_layout_liquid_variables page_type_token
      # Setting up current_tab based on the page type obtained
      set_tab page_type_token

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
  		@search_portal ||= render_to_string :partial => "/portal/search", :locals => { :dynamic_template => "", :placeholder => t('portal.search.placeholder') }     
  	end

    def set_layout_liquid_variables(page_type_token)
      partial = Portal::Page::PAGE_FILE_BY_TOKEN[ page_type_token ]
      _content = render_to_string :file => partial, 
                  :locals => { :dynamic_template => (get_data_for_page(page_type_token) || "") }
      @content_for_layout = _content
    end

    def get_data_for_template(sym)
      common_template = current_portal.template[sym] 
      if preview?
        key = redis_key(sym, current_portal.template[:id])
        common_template = exists(key) ? get_key(key) : current_portal.template[sym]
      end
      common_template
    end

    def get_data_for_page(page_type_token)
      _page_id = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_type_token ]
      page = current_portal.template.pages.find_by_page_type( _page_id )
      page_template = page.content unless page.blank?
      if preview?
        key = redis_key(page_type_token, current_portal.template[:id])
        page_template = get_key(key) if exists(key)
      end
      page_template
    end

    def redis_key label, template_id
      PORTAL_PREVIEW % {:account_id => current_account.id, 
                        :label=> label, 
                        :template_id=> template_id, 
                        :user_id => current_user.id }
    end

    def set_forum_builder
      ActionView::Base.default_form_builder = FormBuilders::RedactorBuilder
    end

end