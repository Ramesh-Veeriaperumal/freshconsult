class Admin::PortalTemplatesController < Admin::AdminController               
  before_filter :build_object, :only => [:index, :update] 

  def update                                                             
    if @portal_template.update_attributes(params[:portal_template])
      flash[:notice] = "Portal template saved successfully"
    end 
    redirect_to :back  
  end                                                             
 
  protected
    def build_object
      @portal = current_account.portals.find_by_id(params[:portal_id]) || current_portal 
      @portal_template = @portal.template || @portal.build_template()
    end
end
