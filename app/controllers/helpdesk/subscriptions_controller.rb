class Helpdesk::SubscriptionsController < ApplicationController
 
  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :load_parent_ticket

  include HelpdeskControllerMethods

  protected
  
    def scoper
      @parent.subscriptions
    end
  
    def item_url
      :back
    end
  
    def create_error
      redirect_to :back
    end
    
    def post_persist
      flash[:notice] = t(:'flash.tickets.monitor.start')
      redirect_to params[:redirect_to].present? ? params[:redirect_to] : item_url
  end
   
  
  def process_destroy_message
      flash[:notice] = t(:'flash.tickets.monitor.stop')
  end
  
end
