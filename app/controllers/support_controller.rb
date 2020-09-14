class SupportController < ApplicationController

  before_filter :check_suspended_account
  skip_before_filter :check_privilege, :set_cache_buster
  layout :resolve_layout
  before_filter :portal_context
  before_filter :strip_url_locale
  before_filter :check_sitemap_feature, only: [:sitemap]
  before_filter :set_language
  before_filter :redirect_to_locale, :except => [:sitemap, :robots]
  around_filter :run_on_slave , :only => [:index,:show],
    :if => proc {|controller| 
      path = controller.controller_path
      path.include?("/solutions") || path.include?("/home") || path.include?("/topics") || path.include?("/discussions")
    }

  include Redis::RedisKeys
  include Redis::PortalRedis
  include Portal::Helpers::SolutionsHelper
  include Portal::Multilingual
  include Redis::OthersRedis
  include Portal::PreviewKeyTemplate
  include SupportTicketRateLimitMethods
  include ApplicationHelper

  helper SupportTicketRateLimitMethods

  before_filter :deny_iframe
  caches_action :show, :index, :new, :robots,
  :if => proc { |controller|
    controller_name = controller.controller_name
    controller.cache_enabled? && 
    !controller_name.eql?('activations') &&
    !controller_name.eql?('search') &&
    !controller_name.eql?('login') &&
    !controller_name.eql?('signups') &&
    !controller_name.eql?('feedback_widgets') &&
    (controller.action_name.eql?('robots') ? true : !controller.safe_send(:current_user)) && 
    controller.safe_send('flash').keys.blank?
  }, 
  :cache_path => proc { |c| 
    cache_path = c.request.original_fullpath.gsub(/\?.*/, '')
    Digest::SHA1.hexdigest("#{c.safe_send(:current_portal).cache_prefix}#{cache_path}#{params[:portal_type]}")
  }
 
  def cache_enabled?
    !(get_portal_redis_key(PORTAL_CACHE_ENABLED) === "false")
  end

  def load_agent_actions(path, priv)
    @agent_actions = []
    @agent_actions <<   { :url => "#{path}",
                          :label => t('portal.preview.view_on_helpdesk'),
                          :icon => "preview" } if privilege?(priv)
    @agent_actions
  end

  def robots
    @crawl_sitemap = current_account.active? && current_account.sitemap_enabled?
    @url = "#{current_portal.url_protocol}://#{current_portal.host}"
    @disallow_languages = current_portal.multilingual? ? current_account.all_portal_languages : []
    respond_to do |format| 
      format.text {render 'robots.txt.erb'}
      format.any {render_404}
    end
  end

  def sitemap
    respond_to do |format|
      format.xml  do 
        xml_text = current_portal.fetch_sitemap
        render :xml => xml_text and return unless xml_text.nil? 
        render_404
      end
      format.any { render_404 }
    end
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
      # Set page flash message
      page_message
      
      # Name of the page to be used to render the static or dynamic page
      @current_page_token = page_token.to_s

      # Setting up meta information for the current page
      page_meta page_token
      
      # Setting up current_tab based on the page type obtained
      current_tab page_token

      # Determine facebook
      @facebook_portal = facebook?
      
      @skip_liquid_compile = false
      
      configure_language_switcher
      
      # Setting up page layout variable
      process_page_liquid page_token

      # Setting dynamic header, footer, layout and misc. information
      process_template_liquid

      # TODO-RAILS3 need to check this
      @skip_liquid_compile = true # if active_layout.present?      
    end

    def preview?
      if User.current
        is_preview = IS_PREVIEW % { :account_id => current_account.id, 
          :user_id => current_user.id, :portal_id => @portal.id}
        (!(get_portal_redis_key(is_preview).blank?  && on_mint_preview.blank?)) && !current_user.blank? && current_user.agent?
      end
    end

  private
  
    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end

    def portal_context
      @portal ||= current_portal
      @preview = preview?
      @portal_template = @portal.fetch_template
      @current_path = request.path

      # !!! Dirty hack Pointing the http_referer to support home if it is in preview mode
      request.env["HTTP_REFERER"] = support_home_url if @preview
    end
    
    # Flash message for the page   
    # The helper method can be found in SupportHelper class      
    def page_message
      output = []
      output << %( <div class="alert alert-with-close notice" id="noticeajax" style="display:none;"></div> )
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
    
    def page_meta page_token
      @page_meta ||= { :title => @page_title || t("portal_meta.titles.#{page_token}") || t('support_title'),
                       :description => @page_description,
                       :keywords => @page_keywords,
                       :canonical => @page_canonical }
                       
      canonical_path = request.original_fullpath.gsub(/\?.*/, '')
      @page_meta[:canonical] ||= "#{@portal.url_protocol}://#{@portal.host}#{canonical_path}"
      @page_meta[:image_url] ||= logo_url
      #additions in canonical URL is removed in the view E.g: /facebook added by FB routing is removed in faceboook view.
      multilingual_meta(page_token) if current_portal.multilingual? 
      @meta = HashDrop.new( @page_meta )
    end

    def multilingual_meta page_token
      return unless [ :solution_home, :solution_category, :article_list, :article_view ].include?(page_token)
      @page_meta[:multilingual_meta] = alternate_version_languages.inject({}) do |result,language|
        result[language.code] = alternate_version_url(language)
        result
      end
    end

    def process_page_liquid(page_token)      
      partial = Portal::Page::PAGE_FILE_BY_TOKEN[ page_token ]
      dynamic_template = nil
      dynamic_template = page_data(page_token) if current_account.layout_customization_enabled? && !on_mint_preview
      _content = render_to_string file: partial, layout: false,
                  locals: { dynamic_template: dynamic_template, request_domain: request.protocol+request.host } if dynamic_template.nil? || !dynamic_template.blank?
                  
                  
      @page_yield = @content_for_layout = _content
    end

    def page_data(page_token)
      page_type ||= Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_token ]
      @current_page = @portal_template.fetch_page_by_type( page_type )
      page_template = @current_page.content unless @current_page.blank?
      if preview? && !on_mint_preview
        draft_page = @portal_template.page_from_cache(page_token) 
        page_template = draft_page[:content] unless draft_page.nil?   
      end
      page_template
    end

    def current_tab token    
      if [ :portal_home, :facebook_home ].include?(token)
        @current_tab ||= "home"
      elsif [ :discussions_home, :discussions_category, :topic_list, :topic_view, :new_topic, :my_topics ].include?(token)
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
      if current_portal.falcon_portal_enable? || current_account.falcon_support_portal_theme_enabled? || on_mint_preview
        Portal::Template::TEMPLATE_MAPPING_RAILS3_FALCON
      else
        Portal::Template::TEMPLATE_MAPPING_RAILS3
      end.each do |t|
        dynamic_template = template_data(t[0]) if current_account.layout_customization_enabled? || on_mint_preview
        _content = render_to_string(:partial => t[1], :layout => false, :handlers => [t[2]],
                    :locals => { :dynamic_template => dynamic_template }) if dynamic_template.nil? || !dynamic_template.blank?
        instance_variable_set "@#{t[0]}", _content
      end
    end

    def template_data(sym)
      begin
        data = @portal_template[sym] 
        data = @portal_template.get_draft[sym] if preview? && @portal_template.get_draft && !on_mint_preview
      rescue Exception => e
        Rails.logger.info "Exception on head customization :::: #{e.backtrace}"
        NewRelic::Agent.notice_error(e,{:description => "Error on head customization"})
        data = nil
      end
      data
    end

    def resolve_layout
      facebook? ? "facebook" : "support"
    end

    def facebook?
      params[:portal_type] == "facebook"
    end

    def check_forums_state
      unless current_user && current_user.agent?
        redirect_to support_home_path if current_account.features?(:hide_portal_forums)
      end
    end

    def forums_enabled?
      feature?(:forums) && allowed_in_portal?(:open_forums) && !feature?(:hide_portal_forums)
    end

    def check_forums_access
      render_404 unless feature?(:forums) 
    end

    protected

    def render_tracker
      File.open("#{Rails.root}/public/images/misc/spacer.gif", 'rb') do |f|
        send_data f.read, :type => "image/gif", :disposition => "inline"
      end
    end

  private
  def strip_url_locale
    # request.fullpath will return the current path without the url_locale
    # We are redirecting to fullpath here cos users shouldn't be able to access language specific urls when ... 
    # multilingual feature is not enabled.
    redirect_to request.fullpath if params[:url_locale].present? && !current_portal.multilingual?
  end

  def set_language
    Language.for_current_account.make_current and return unless current_account.multilingual?
    Language.set_current(
      request_language: http_accept_language.language_region_compatible_from(I18n.available_locales), 
      url_locale: params[:url_locale])
    override_default_locale
  end

  def agent?
    current_user && current_user.agent?
  end

  def public_request?
    current_user.nil?
  end

  def redirect_to_locale
    if current_portal.multilingual? && !facebook? && (params[:url_locale] != Language.current.code)
      flash.keep 
      redirect_to request.fullpath.prepend("/#{Language.current.code}") 
    end
  end

  def override_default_locale
    # We should not override the locale if the logged in user's language is not present in the portal languages.
    # We show the labels in user's language and the articles in Language.current.
    return if current_user.present? && !current_account.valid_portal_language?(Language.for_current_user)
    #We are doing this for non-logged in users as it's better we show them everything(not only solutions) 
    # in the current locale i.e Language.current instead of the account's language.
    I18n.locale = Language.current.code.to_sym
  end

  def alternate_version_languages
    return current_account.all_portal_language_objects unless @solution_item
    @solution_item.portal_available_versions
  end

  def check_version_availability
    return unless current_account.multilingual?
    return if @solution_item && @solution_item.current_available?
    render_404 and return if unscoped_fetch.blank?
    flash[:warning] = version_not_available_msg(controller_name.singularize)
    redirect_to support_home_path
  end

  def check_suspended_account
    unless current_account.active? || current_account.subscription.updated_at > 1.day.ago
      # Account suspended more than 1 day ago
      flash[:notice] = t('flash.general.portal_blocked')
      redirect_to support_login_path
    end
  end

  def render_request_error(code, status, params_hash = {})
    @error = RequestError.new(code, params_hash)
    render '/request_error', status: status
  end

  def check_sitemap_feature
    render_404 unless current_account.sitemap_enabled?
  end

  def deny_iframe
    return unless request.format.html?
    return unless current_account.account_additional_settings.security[:deny_iframe_embedding]

    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
  end
end
