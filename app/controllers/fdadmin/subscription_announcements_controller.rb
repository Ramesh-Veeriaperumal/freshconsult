class Fdadmin::SubscriptionAnnouncementsController < Fdadmin::DevopsMainController

	skip_filter :run_on_slave
	before_filter :load_object, :only => [:update, :destroy ]

	def index
    notifications = {}
    if params[:request_method] == "maintenance"
      notifications[:maintenance] = scoper.maintenance_notifications
    else
      notifications[:product] = scoper.product_notifications
    end
    respond_to do |format|
      format.json do 
        render :json => notifications
      end
    end
  end
    
  def create
    result = {}
    @announcement = scoper.new(request.query_parameters[:subscription_announcement])   
    if @announcement.save
      result[:status] = "success"
    else
      result[:status] = "error"
    end
    respond_to do |format|
      format.json do 
        render :json => result
      end
    end
  end
                                      
  def update      
    if @announcement.update_attributes(request.query_parameters[:subscription_announcement])
      render :json => {:status => "success"}
    else
      render :json => {:status => "error"}
    end
  end
                          
  def destroy                                         
    if @announcement.destroy      
      render :json => {:status => "success"} 
    else
      render :json => {:status => "error"} 
    end
  end                    
    
  protected
    def scoper
      SubscriptionAnnouncement
    end            
    
    def load_object
      @announcement = scoper.find(params[:id]) 
    end         
    
end
