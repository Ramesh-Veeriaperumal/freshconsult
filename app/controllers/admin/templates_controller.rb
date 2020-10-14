class Admin::TemplatesController < Admin::AdminController  
  include Portal::TemplateActions
  include Redis::OthersRedis
  include Cache::Memcache::Portal
  include Cache::Memcache::Portal::Template
  include Portal::ColourConstants

  before_filter :build_objects,  :only => [:show, :update, :soft_reset, :restore_default, :publish]
  before_filter :clear_preview_session, :default_liquids , :only => :show
  before_filter :clear_preview_session
  before_filter(:only => :update) do |c|
   #validating the syntax before persisting.
    if params[:portal_template].present?
      custom_css = c.request.params[:portal_template][:custom_css]
      c.safe_send(:css_syntax?, custom_css) unless custom_css.nil?
      if current_account.falcon_support_portal_theme_enabled? || @portal.falcon_portal_enable?
        Portal::Template::TEMPLATE_MAPPING_FILE_BY_TOKEN_FALCON
      else
        Portal::Template::TEMPLATE_MAPPING_FILE_BY_TOKEN
      end.each do |key,file|
        c.safe_send(:liquid_syntax?, c.request.params[:portal_template][key.to_sym])
      end
    end
  end

  def show
    @falcon_portal_enabled = @portal.falcon_portal_enable?
    @portal = @portal_template.portal  
    @falcon_support_portal_theme_enabled = current_account.falcon_support_portal_theme_enabled?
  end

  def publish
    @portal_template.publish!
    flash[:notice] = t("admin.portal_settings.flash.portal_published_success")
    redirect_to admin_portal_template_path( @portal ) and return
  end

  def restore_default
    @portal_template.reset_to_default
    flash[:notice] = t("admin.portal_settings.flash.portal_reset_success")
    redirect_to admin_portal_template_path( @portal ) and return
  end

  def update
    @portal_template = scoper.fetch_template if params[:apply_new_skin]
    merge_preferences if params[:portal_template].present?
    if params[:apply_new_skin] && !@portal.falcon_portal_enable?
        apply_new_skin  
        remove_all_preview_redis_key(current_account,@portal)
        clear_cache_apply_portal(@portal.portal_url,current_account.id)
        current_account.rollback(:mint_portal_applicable) unless support_mint_applicable?
        redirect_to support_preview_path
        set_portal_redis_key(is_preview_key, true,300)
        return
    end
    set_preview_and_redirect_mint_ui if params[:mint_preview_button]

    if params[:publish_button]
      clear_main_portal_cache(current_account.id)
      save_and_publish
    else
      flash[:notice] = t("admin.portal_settings.flash.portal_saved_success") unless params[:preview_button]
    end

    respond_to do |format|
      format.html { 
        if params[:preview_button]
          #remove preview key
          unset_mint_preview
          set_preview
          preview_url = support_home_path
          set_preview_and_redirect(preview_url) 
        end
      }
      format.js
    end
  end  

  def clear_preview
    render :text => "success"
  end

  def soft_reset
    @portal_template.clear_preview
    properties = params[:portal_template]
    @portal_template.soft_reset!(properties)
    flash[:notice] = t("admin.portal_settings.flash.portal_reset_success")
    redirect_to "#{admin_portal_template_path( @portal )}##{properties[0]}"
  end                                                          
 
  private

    def save_and_publish
      @portal_template.publish!
      @portal_template.clear_preview
      properties = params[:portal_template]
      @portal_template.soft_reset!(properties)
      @portal_template.clear_cache!
      flash[:notice] = t("admin.portal_settings.flash.portal_published_success")
    end

    def enable_preview
      if support_mint_applicable_portal?(@portal)
        unset_preview 
        set_mint_preview 
      else
        unset_mint_preview
        set_preview
      end
    end

    def merge_preferences
      if params[:portal_template][:preferences].present?
          sanitize_preferences
          params[:portal_template][:preferences] = @portal_template.preferences.merge(params[:portal_template][:preferences])
        end
        @portal_template.attributes = params[:portal_template]
        @portal_template.draft! unless params[:apply_new_skin]
    end

    def apply_new_skin
      template = @portal_template.get_draft || @portal_template
      current_preferences = template.preferences.symbolize_keys
      @portal_template.preferences = FALCON_COLOURS.merge(current_preferences.diff(OLD_COLOURS))
      @portal_template.publish!
      @portal_template.clear_cache! 
      clear_preview_session
      @portal.preferences[:falcon_portal_key] = "true"
      @portal.save
    end

    def set_preview_and_redirect_mint_ui
      enable_preview
      if current_portal == @portal
          redirect_to support_preview_path(:mint_preview => "true") and return
        else
          redirect_to support_preview_url(:host => @portal.host,:mint_preview =>"true") and return
        end
    end

    def build_objects
      @portal_template = scoper.fetch_template.get_draft || scoper.fetch_template
    end

    def default_liquids
      @show_raw_liquid = true
      if current_account.falcon_support_portal_theme_enabled? || @portal.falcon_portal_enable?
        Portal::Template::TEMPLATE_MAPPING_FALCON
      else
        Portal::Template::TEMPLATE_MAPPING
      end.each {
        |t| @portal_template[t[0]] = render_to_string(:partial => t[1]) if (@portal_template[t[0]].nil?)
      }  
    end

    def sanitize_preferences
      pref = @portal_template.default_preferences.keys - [:baseFont, :headingsFont, :nonResponsive]
      params[:portal_template][:preferences].each do |key, value|
        col = key.to_sym
        next if pref.exclude?(col)
        params[:portal_template][:preferences].delete(col) unless value =~ Portal::HEX_COLOR_REGEX
      end
    end
end