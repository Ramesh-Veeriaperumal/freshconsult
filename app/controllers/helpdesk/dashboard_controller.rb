class Helpdesk::DashboardController < ApplicationController
  
  helper 'helpdesk/tickets' #by Shan temp
  include Reports::ScoreboardReport
  include Mobile::MobileHelperMethods

  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :set_mobile, :only => [:index]

  def index
    @items = recent_activities(params[:activity_id]).paginate(:page => params[:page], :per_page => 10)
    if request.xhr?
      render(:partial => "ticket_note", :collection => @items)
    end
    #for leaderboard widget
    @champions = list_of_champions()
  end
  
  def latest_activities
    previous_id = params[:previous_id]
    activities = Helpdesk::Activity.freshest(current_account).activity_since(previous_id).permissible(current_user)
    render :partial => "ticket_note", :collection => activities
  end
  
  def latest_summary
    render :partial => "summary"
  end

  protected
    def recent_activities(activity_id)
      if activity_id
        Helpdesk::Activity.activty_before(current_account,activity_id).permissible(current_user) unless activity_id == "0"
      else
        Helpdesk::Activity.freshest(current_account).permissible(current_user)
      end
    end

end
