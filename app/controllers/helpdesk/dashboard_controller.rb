class Helpdesk::DashboardController < ApplicationController
  
  helper 'helpdesk/tickets' #by Shan temp

  before_filter { |c| c.requires_permission :manage_tickets }

  def index
    @items = recent_activities.paginate(:page => params[:page], :per_page => 10)
    if request.xhr?
      render(:partial => "ticket_note", :collection => @items)
    end
  end
  
  protected
    def recent_activities
      Helpdesk::Activity.freshest(current_account)
    end

end
