class Admin::TemplatesController < Admin::AdminController  
  include Portal::TemplateActions
  include MemcacheKeys

  before_filter :build_objects, :default_liquids, :set_forum_builder, :clear_preview_session
  
  before_filter(:only => [:update]) do |c|
    custom_css = c.request.params[:portal_template][:custom_css]
    c.send(:css_syntax?, custom_css) unless custom_css.nil?
    Portal::Template::TEMPLATE_MAPPING_FILE_BY_TOKEN.each do |key,file|
      c.send(:liquid_syntax?, c.request.params[:portal_template][key.to_sym])
    end
  end

  def publish
    @portal_template.publish!
    flash[:notice] = "Portal changes published successfully."
    redirect_to admin_portal_template_path( @portal ) and return
  end

  def restore_default
    @portal_template.reset_to_default
    flash[:notice] = "Portal changes reseted successfully."
    redirect_to admin_portal_template_path( @portal ) and return
  end

  def update
    @portal_template.attributes = @portal_template.attributes.merge params[:portal_template]
    @portal_template.draft!
    if params[:preview_button]
      session[:preview_button] = true
      @redirect_to_portal_url = support_solutions_url
    end
    flash[:notice] = "Portal template saved successfully."
    build_objects
    render "update.rjs"
  end  

  def soft_reset
    properties = params[:portal_template].split(":")
    @portal_template.soft_reset!(properties)
    flash[:notice] = "Portal template reseted successfully."
    redirect_to "#{admin_portal_template_path( @portal )}##{properties[0]}"
  end                                                          
 
  private
    def build_objects
      @portal_template = scoper.template.get_draft || scoper.template
      @cached_properties = @portal_template.changes.symbolize_keys.keys
    end

    def default_liquids
      Portal::Template::TEMPLATE_MAPPING.each {
        |t| @portal_template[t[0]] = render_to_string(:partial => t[1], 
          :content_type => 'text/plain') if (@portal_template[t[0]].nil?)
      }   
    end
end
