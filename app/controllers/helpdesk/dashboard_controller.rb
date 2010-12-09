class Helpdesk::DashboardController < ApplicationController
  layout 'helpdesk/layout'
  
  helper 'helpdesk/tickets' #by Shan temp

  before_filter { |c| c.requires_permission :manage_tickets }

  def index
    respond_to do |format|
      format.html  do
        @items = Helpdesk::Note.freshest(current_account).exclude_source('meta').paginate(:page => params[:page], :per_page => 10)
      end
      format.atom do
        @items = Helpdesk::Note.freshest(current_account).exclude_source('meta').paginate(:page => 1, :per_page => 20)
      end
    end
  end

end
