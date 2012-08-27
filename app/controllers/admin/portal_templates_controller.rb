class Admin::PortalTemplatesController < Admin::AdminController               
  before_filter :build_object, :only => [:index, :update]
  before_filter [:get_template, :get_pages], :only => [:index]

  def update                                             
    if params[:preview_button] || !@portal_template.update_attributes(params[:portal_template])
      render :action => 'new'
	  else         
      flash[:notice] = "Portal template saved successfully"
    end
    redirect_to :back  
  end                                                             
 
  protected
    def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id]) || current_portal
    end

    def build_object
      unless scoper.template
        scoper.build_template().save()
        redirect_to :action => :index
      end
      @portal_template = scoper.template
    end

    def get_template
      Portal::Template::TEMPLATE_MAPPING.each {
        |t| @portal_template[t[0]] = render_to_string(:partial => t[1], :content_type => 'text/plain') if (@portal_template[t[0]].nil?)
        }   
    end
                                                           
    def get_pages                  
      @page_types = Portal::Page::PAGE_TYPE_OPTIONS
      @portal_pages = @portal_template.pages
      @available_pages = @portal_pages.map{ |p| p[:page_type] }
    end

end
