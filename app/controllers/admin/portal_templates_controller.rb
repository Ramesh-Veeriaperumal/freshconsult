class Admin::PortalTemplatesController < Admin::AdminController               
  before_filter :build_object, :only => [:index, :update] 
  before_filter :get_pages, :only => [:index] 

  def update                                             
    if params[:preview_button] || !@portal_template.update_attributes(params[:portal_template])
      render :action => 'new'
	  else         
      flash[:notice] = "Portal template saved successfully"
    end 
    redirect_to :back  
  end                                                             
 
  protected
    def build_object
      @portal = current_account.portals.find_by_id(params[:portal_id]) || current_portal
      @portal_template = @portal.template || @portal.build_template()
    end
                                                           
    def get_pages                  
      @page_types = Portal::Page::PAGE_TYPE_OPTIONS
      @portal_pages = @portal_template.pages
    end
end
