class SupportController < ApplicationController

  before_filter :portal_context, :page_message
  include RedisKeys

  caches_action :show, :index, :new,
  :if => proc { |controller|
    controller_name = controller.controller_name
    controller.cache_enabled? && 
    !controller_name.eql?('feedback_widgets') &&
    (controller_name.eql?("theme") || !controller.send(:current_user)) && 
    controller.send('flash').keys.blank?
  }, 
  :cache_path => proc { |c| 
    "#{c.send(:current_portal).cache_prefix}#{c.request.request_uri}" 
  }
 
  def cache_enabled?
    !(get_key(PORTAL_CACHE_ENABLED) === "false")
  end

  protected
    def set_portal_page page_token
      @skip_liquid_compile = false
      # Setting up page layout variable
      process_page_liquid page_token

      # Setting up current_tab based on the page type obtained
      current_tab page_token

      # Setting dynamic header, footer, layout and misc. information
      process_template_liquid
      @skip_liquid_compile = true if active_layout.present?
    end

    def preview?
      if User.current
        is_preview = IS_PREVIEW % { :account_id => current_account.id, 
          :user_id => current_user.id, :portal_id => @portal.id}
        !get_key(is_preview).blank? && !current_user.blank? && current_user.agent?
      end
    end
  private

    def portal_context
      @portal ||= current_portal
      @preview = preview?
      @portal_template = @portal.fetch_template

      # !!! Dirty hack Pointing the http_referer to support home if it is in preview mode
      request.env["HTTP_REFERER"] = support_home_url if @preview
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
      dynamic_template = nil
      dynamic_template = page_data(page_token) if feature?(:layout_customization)
      _content = render_to_string :file => partial,
                  :locals => { :dynamic_template => dynamic_template } if dynamic_template.nil? || !dynamic_template.blank?
      @content_for_layout = _content
    end

    def page_data(page_token)
      page_type ||= Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_token ]
      @current_page = @portal_template.fetch_page_by_type( page_type )
      page_template = @current_page.content unless @current_page.blank?
      if preview?
        draft_page = @portal_template.page_from_cache(page_token)
        page_template = draft_page[:content] unless draft_page.nil?
      end
      page_template
    end

    def current_tab token    
      if [ :portal_home ].include?(token)
        @current_tab ||= "home"
      elsif [ :discussions_home, :topic_list, :topic_view, :new_topic ].include?(token)
        @current_tab ||= "forums"
      elsif [ :solution_home, :solution_category, :article_list, :article_view ].include?(token)
        @current_tab ||= "solutions"
      elsif [ :ticket_list, :ticket_view ].include?(token)
        @current_tab ||= "tickets"
      elsif [ :search ].include?(token)
        @current_tab ||= "search"
      end
    end

    def process_template_liquid
      Portal::Template::TEMPLATE_MAPPING.each do |t|
        dynamic_template = template_data(t[0]) if feature?(:layout_customization)
        _content = render_to_string :partial => t[1], 
                    :locals => { :dynamic_template => dynamic_template } if dynamic_template.nil? || !dynamic_template.blank?
        instance_variable_set "@#{t[0]}", _content
      end
    end

    def template_data(sym)
      data = @portal_template[sym] 
      data = @portal_template.get_draft[sym] if preview? && @portal_template.get_draft
      data
    end
    
end