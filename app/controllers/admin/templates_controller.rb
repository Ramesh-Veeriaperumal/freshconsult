class Admin::TemplatesController < Admin::AdminController  
  include RedisKeys

  
  before_filter :build_object, :only => [:show, :update, :soft_reset, :publish, :restore_to_default]
  before_filter [:get_template, :get_pages], :only => [:show]
  before_filter :syntax_validation, :redis_save, :only => :update
  before_filter :update_changes, :only => [:show, :publish]
  before_filter :redis_delete, :only => :soft_reset
  before_filter :set_forum_builder, :clear_preview_session
  
  def show
    @theme_colors = @portal.preferences.map{ |k, p| "$#{k}:#{p};" }.join("")
    default_custom_css = render_to_string(:file => "#{Rails.root}/public/src/portal/portal.scss")    
  end

  def publish
    @portal_template.save
    flash[:notice] = "Portal changes published successfully."
    redirect_to admin_portal_template_path( @portal ) and return
  end

  def restore_to_default
    @portal_template.reset_to_default
    flash[:notice] = "Portal changes reseted successfully."
    redirect_to admin_portal_template_path( @portal ) and return
  end

  def update
    if params[:preview_button]
      session[:preview_button] = true
      @redirect_to_portal_url = support_solutions_url
      redirect_to support_solutions_url and return
    end
    flash[:notice] = "Portal template saved successfully."
    portal_template = params[:portal_template].keys.size > 1 ? :header : params[:portal_template].keys[0]
    redirect_to "#{admin_portal_template_path( @portal )}##{portal_template}"
  end  

  def soft_reset
    flash[:notice] = "Portal template reseted successfully."
    portal_template = params[:portal_template].split(":")[0]
    redirect_to "#{admin_portal_template_path( @portal )}##{portal_template}"
  end                                                          
 
  private
    def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id]) || current_portal
    end

    def build_object
      @portal_template = scoper.template
      unless scoper.template
        @portal_template = scoper.build_template()
        @portal_template.save()
      end
    end

    def get_template
      Portal::Template::TEMPLATE_MAPPING.each {
        |t| @portal_template[t[0]] = render_to_string(:partial => t[1], :content_type => 'text/plain') if (@portal_template[t[0]].nil?)
      }   
    end
                                                           
    def get_pages                  
      @page_types = Portal::Page::PAGE_TYPE_OPTIONS
      @page_groups = Portal::Page::PAGE_GROUPS
      @portal_pages = @portal_template.pages
      @available_pages = @portal_pages.map{ |p| p[:page_type] }
    end

    def redis_key label, template_id
      PORTAL_PREVIEW % {:account_id => current_account.id, 
                        :label=> label, 
                        :template_id=> template_id, 
                        :user_id => current_user.id
                      }
    end

    def redis_save
      params[:portal_template].each do |key, value|
        rkey = redis_key(key, @portal_template[:id])
        value = value.to_json if key.eql?("preferences")
        set_key(rkey, value)
      end
    end

    def update_changes
      [:preferences, :custom_css, :header, :footer, :layout].each do |key|
        rkey = redis_key(key, @portal_template[:id])
        redis_data = get_key(rkey)
        unless redis_data.nil?
          instance_variable_set "@#{key}_from_redis", true
          redis_data = JSON.parse(redis_data).symbolize_keys! if key.eql?(:preferences)
          @portal_template[key] =  redis_data 
        end
      end
    end

    def redis_delete
      portal_templates = params[:portal_template].split(":")
      portal_templates.each do |template|
        rkey = redis_key(template, @portal_template[:id])
        remove_key(rkey)
      end
    end

    def set_forum_builder
      ActionView::Base.default_form_builder = FormBuilders::CodeMirrorBuilder
    end

    def clear_preview_session
      session.delete(:preview_button)
    end 

    def syntax_validation
      Portal::Template::TEMPLATE_MAPPING_FILE_BY_TOKEN.each do |key,file|
        liquid_data = params[:portal_template][key.to_sym]
        begin
          Liquid::Template.parse(liquid_data)
        rescue Exception => e
          flash[:error] = e.to_s
          return redirect_to "#{admin_portal_template_path( @portal )}#header"
          #NewRelic::Agent.notice_error(e)
        end  
      end
    end   

end
