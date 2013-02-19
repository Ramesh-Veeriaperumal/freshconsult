class SupportController < ApplicationController
  layout 'portal'

  before_filter :portal_context, :redactor_form_builder, :page_message
  include RedisKeys
 
  protected
    def set_portal_page page_token
      @skip_liquid_compile = false
      # Setting up page layout variable
      process_page_liquid page_token

      # Setting up current_tab based on the page type obtained
      current_tab page_token

      # Setting dynamic header, footer, layout and misc. information
      process_template_liquid
      @skip_liquid_compile = true
    end

    def preview?
      if User.current
        is_preview = IS_PREVIEW % { :account_id => current_account.id, 
        :user_id => User.current.id, :portal_id => @portal.id}
        !get_key(is_preview).blank? && !current_user.blank? && current_user.agent?
      end
    end

  private

    def portal_context
      @portal ||= current_portal
      @preview = preview?
    end

    def redactor_form_builder
      ActionView::Base.default_form_builder = FormBuilders::RedactorBuilder
    end
    
    # Flash message for the page   
    # The helper method can be found in SupportHelper class      
    def page_message
      output = []
      [:notice, :warning, :error].collect do |type| 
        if flash[type]          
          output << %( <div id="#{type}" class="alert alert-page alert-#{type}"> )
          output << %( <button type="button" class="close" data-dismiss="alert">&times;</button> )
          output << flash[type]
          output << %( </div> )          
        end
      end
      @page_message ||= output.join(" ")
    end

    def process_page_liquid(page_token)      
      partial = Portal::Page::PAGE_FILE_BY_TOKEN[ page_token ]
      dynamic_template = ""
      dynamic_template = (page_data(page_token) || "") if feature?(:layout_customization)
      _content = render_to_string :file => partial,
                  :locals => { :dynamic_template => dynamic_template }
      @content_for_layout = _content
    end

    def page_data(page_token)
      page_type ||= Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_token ]
      @current_page = current_portal.template.pages.find_by_page_type( page_type ) || 
                        current_portal.template.pages.new
      page_template = @current_page.content unless @current_page.blank?
      if preview?
        draft_page = current_portal.template.page_from_cache(page_token)
        page_template = draft_page[:content] unless draft_page.nil?
      end
      page_template
    end

    def current_tab token    
      if [ :portal_home ].include?(token)
        @current_tab ||= "home"
      elsif [ :discussions_home, :topic_list, :topic_view, :new_topic ].include?(token)
        @current_tab ||= "forums"
      elsif [ :solution_home, :article_list, :article_view ].include?(token)
        @current_tab ||= "solutions"
      elsif [ :ticket_list, :ticket_view ].include?(token)
        @current_tab ||= "tickets"
      elsif [ :search ].include?(token)
        @current_tab ||= "search"
      end
    end

    def process_template_liquid
      Portal::Template::TEMPLATE_MAPPING.each_with_index do |t, t_i|
        dynamic_template = template_data(t[0]) if feature?(:layout_customization)
        _content = render_to_string :partial => t[1], 
                    :locals => { :dynamic_template => dynamic_template }
        instance_variable_set "@#{t[0]}", _content
      end
    end

    def template_data(sym)
      data = current_portal.template[sym] 
      data = current_portal.template.get_draft[sym] if preview? && current_portal.template.get_draft
      data
    end
    
end