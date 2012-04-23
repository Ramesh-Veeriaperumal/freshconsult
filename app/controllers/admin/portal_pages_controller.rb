class Admin::PortalPagesController < Admin::AdminController               
  before_filter :build_object, :only => [:new, :create, :edit, :update] 
  before_filter :load_page_types, :only => [:new, :edit]
  layout false                                                                                  
  
  def create                                                                                     
    if @portal_page.save
      flash[:notice] = "New page saved successfully"
    end
    render :partial => "/admin/portal_templates/portal_pages", :object => @portal.template.pages
  end                 
  
  def edit                                             
    @portal_page = scoper.template.pages.find_by_id(params[:id])
  end                                                
  
  def update
    if @portal_page.update_attributes(params[:portal_page])
      flash[:notice] = "Page saved successfully"
    end 
    redirect_to admin_portal_templates_path(@portal)
  end
  
  protected  
    
    def scoper
      @portal = current_account.portals.find_by_id(params[:portal_id]) || current_portal
    end
      
    def build_object
      scoper
      page = {:account_id => @portal.account, :template_id => @portal.template}.merge(params[:portal_page]||{})
      @portal_page = @portal.template.pages.new(page)
    end

    def load_page_types
      @page_types = Portal::Page::PAGE_TYPE_OPTIONS
    end
    
end