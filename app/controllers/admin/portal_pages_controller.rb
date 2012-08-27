class Admin::PortalPagesController < Admin::AdminController               
  before_filter :build_object, :only => [:new, :create]
  before_filter :find_object, :only => [:edit, :update]
  before_filter :get_raw_page, :except => [:create, :update]
  
  layout false

  def create
    @portal_page.update_attributes(params[:portal_page])
    if @portal_page.save
      flash[:notice] = "Page successfully customized with your changes"
    end
    redirect_to :back
  end

  def update    
    if @portal_page.update_attributes(params[:portal_page])
      flash[:notice] = "Page customization updated successfully"
    end
    redirect_to :back
  end
  
  protected  
    
    def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id]) || current_portal
    end
      
    def build_object      
      page = { :page_type => params[:page_type] }
      @portal_page = scoper.template.pages.new(page)
    end

    def find_object
      @portal_page = scoper.template.pages.find_by_id(params[:id])
    end

    def get_raw_page
      @portal_page[:content] = render_to_string(:file => @portal_page.default_page, :content_type => 'text/plain') if @portal_page[:content].blank?
    end
    
end