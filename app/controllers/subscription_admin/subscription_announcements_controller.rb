class SubscriptionAdmin::SubscriptionAnnouncementsController < ApplicationController
  include AdminControllerMethods
  before_filter :build_object, :only => [ :new ]
  before_filter :load_object, :only => [ :edit, :update, :destroy ]        
  before_filter :set_selected_tab
  
  def index
    @announcements = scoper.all
  end            
    
  def create
    @announcement = scoper.new(params[:subscription_announcement])   
    if @announcement.save
      redirect_to(admin_subscription_announcements_path, :notice => 'A new Announcement was successfully created.')
    else
      render :action => "new"
    end
  end
                                      
  def update      
    @announcement = scoper.find(params[:id])
    if @announcement.update_attributes(params[:subscription_announcement])
      redirect_to(admin_subscription_announcements_path, :notice => 'Announcement was successfully updated.')
    else
      render :action => "edit"
    end
  end
                          
  def destroy                                         
    @announcement.destroy      
    redirect_to(admin_subscription_announcements_path)
  end                    
    
  protected
    def scoper
      SubscriptionAnnouncement
    end            
    
    def load_object
      @announcement = scoper.find(params[:id]) 
    end         
    
    def build_object
      @announcement = scoper.new
    end 
    
    def set_selected_tab
       @selected_tab = :announcements
    end
end
