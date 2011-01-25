class Helpdesk::DashboardController < ApplicationController
  
  helper 'helpdesk/tickets' #by Shan temp

  before_filter { |c| c.requires_permission :manage_tickets }

  def index
    respond_to do |format|
      format.html  do
        @items = recent_activities.paginate(:page => params[:page], :per_page => 10)
      end
      format.atom do
        @items = recent_activities.paginate(:page => 1, :per_page => 20)
      end
    end
  end
  
  protected
    def recent_activities
      Helpdesk::Activity.freshest(current_account)
    end

end
