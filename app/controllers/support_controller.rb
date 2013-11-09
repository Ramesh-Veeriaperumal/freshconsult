class SupportController < ApplicationController

  skip_before_filter :check_privilege, :set_cache_buster
  layout :resolve_layout
  before_filter :portal_context, :page_message
  include Redis::RedisKeys
  include Redis::PortalRedis

  caches_action :show, :index, :new,
  :if => proc { |controller|
    controller_name = controller.controller_name
    controller.cache_enabled? && 
    !controller_name.eql?('search') &&
    !controller_name.eql?('login') &&
    !controller_name.eql?('feedback_widgets') &&
    (controller_name.eql?("theme") || !controller.send(:current_user)) && 
    controller.send('flash').keys.blank?
  }, 
  :cache_path => proc { |c| 
    "#{c.send(:current_portal).cache_prefix}#{c.request.request_uri}" 
  }
  
  def cache_enabled?
    !(get_portal_redis_key(PORTAL_CACHE_ENABLED) === "false")
  end

  protected

    def allow_monitor?
      params[:user_id] = current_user.id if (params[:user_id].nil?)
      unless privilege?(:manage_forums)
        if (!params[:user_id].blank? && params[:user_id].to_s!=current_user.id.to_s)
          @errors = {:error=>"Permission denied for user"}
          respond_to do |format|
            format.xml {
              render :xml => @errors.to_xml(:root=>:errors),:status=>:forbidden
             }
             format.json{
              render :json => {:errors=>@errors}.as_json,:status=>:forbidden
             }
          end
        end 

      end
    end


    def set_portal_page page_token
      # Name of the page to be used to render the static or dynamic page
      @current_page_token = page_token.to_s

      # Setting up current_tab based on the page type obtained
      current_tab page_token

      # Determine facebook
      @facebook_portal = facebook?
      
      @skip_liquid_compile = false
      
      # Setting up page layout variable
      process_page_liquid page_token

      # Setting dynamic header, footer, layout and misc. information
      process_template_liquid

      @skip_liquid_compile = true # if active_layout.present?      
    end

    def preview?
      if User.current
        is_preview = IS_PREVIEW % { :account_id => current_account.id, 
          :user_id => current_user.id, :portal_id => @portal.id}
        !get_portal_redis_key(is_preview).blank? && !current_user.blank? && current_user.agent?
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
          flash[type] = nil
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

      @page_yield = @content_for_layout = _content
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
      if [ :portal_home, :facebook_home ].include?(token)
        @current_tab ||= "home"
      elsif [ :discussions_home, :topic_list, :topic_view, :new_topic, :my_topics ].include?(token)
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

    def resolve_layout
      facebook? ? "facebook" : "support"
    end

    def facebook?
      params[:portal_type] == "facebook"
    end
end
