class Admin::TemplatesController < Admin::AdminController  
  include Portal::TemplateActions

  before_filter :build_objects,  :only => [:show, :update, :soft_reset, :restore_default, :publish]
  before_filter :clear_preview_session, :default_liquids , :only => :show
  before_filter :clear_preview_session, :only => :clear_preview

  
  before_filter(:only => :update) do |c| #validating the syntax before persisting.
    custom_css = c.request.params[:portal_template][:custom_css]
    c.send(:css_syntax?, custom_css) unless custom_css.nil?
    Portal::Template::TEMPLATE_MAPPING_FILE_BY_TOKEN.each do |key,file|
      c.send(:liquid_syntax?, c.request.params[:portal_template][key.to_sym])
    end
  end

  def show
    @portal = @portal_template.portal    
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
    # Merging preferences as it may be used in multiple forms
    if params[:portal_template][:preferences].present?
      sanitize_preferences
      params[:portal_template][:preferences] = @portal_template.preferences.merge(params[:portal_template][:preferences])
    end

    @portal_template.attributes = params[:portal_template]

    @portal_template.draft!

    if params[:publish_button]
      @portal_template.publish!
      flash[:notice] = t("admin.portal_settings.flash.portal_published_success")
    else
      flash[:notice] = t("admin.portal_settings.flash.portal_saved_success") unless params[:preview_button]
    end

    respond_to do |format|
      format.html { 
        if params[:preview_button]
          preview_url = support_home_path
          set_preview_and_redirect(preview_url) 
        end
      }
    end
  end  

  def clear_preview
    render :text => "success"
  end

  def soft_reset
    properties = params[:portal_template]
    @portal_template.soft_reset!(properties)
    flash[:notice] = t("admin.portal_settings.flash.portal_reset_success")
    redirect_to "#{admin_portal_template_path( @portal )}##{properties[0]}"
  end                                                          
 
  private
    def build_objects
      @portal_template = scoper.fetch_template.get_draft || scoper.fetch_template
    end

    def default_liquids
      Portal::Template::TEMPLATE_MAPPING.each {
        |t| @portal_template[t[0]] = render_to_string(:partial => t[1], 
          :content_type => 'text/plain') if (@portal_template[t[0]].nil?)
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
