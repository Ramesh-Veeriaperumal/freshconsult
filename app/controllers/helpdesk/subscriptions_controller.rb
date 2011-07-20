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
      @ticket = @parent
      @subscription = current_user && @parent.subscriptions.find(
        :first, 
        :conditions => {:user_id => current_user.id})
              
      flash.now[:notice] = t(:'flash.tickets.monitor.start')
      respond_to do |format|
        format.html { redirect_to params[:redirect_to].present? ? params[:redirect_to] : item_url }
        format.js { render :partial => "toggle_monitor" }
      end
    end

    def process_destroy_message
      flash.now[:notice] = t(:'flash.tickets.monitor.stop')
    end
    
    def after_destory_js
      process_destroy_message
      respond_to do |format|
        format.js { render :partial => "toggle_monitor" }
      end
    end
end
