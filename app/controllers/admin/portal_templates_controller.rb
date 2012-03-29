class Admin::PortalTemplatesController < Admin::AdminController               
  before_filter :build_object, :only => :new 

  def create      
    puts "Paramters for Create #{params[:portal_template].inspect}"          
    @portal_template = current_portal.build_portal_template(params[:portal_template])   
    if @portal_template.save
      flash[:notice] = "Portal template saved successfully"
    end
    redirect_to :back  
  end                                                             
 
  protected
    def scoper
      current_portal
    end
                     
    def build_object
      @portal_template = current_portal.build_portal_template
    end
end
