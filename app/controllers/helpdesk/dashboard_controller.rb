class Helpdesk::DashboardController < ApplicationController

  helper 'helpdesk/tickets' #by Shan temp
  include Reports::GamificationReport

  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :set_mobile, :only => [:index]
  
  prepend_before_filter :silence_logging, :only => :latest_activities
  after_filter   :revoke_logging, :only => :latest_activities
  
  before_filter :load_items, :only => [:activity_list]
  before_filter :set_selected_tab

  def index
    if request.xhr? and !request.headers['X-PJAX']
      load_items
      render(:partial => "ticket_note", :collection => @items)
    end
    #for leaderboard widget
    # @champions = champions
  end

  def activity_list
    render :partial => "activities"
  end
  
  def latest_activities
    begin
      previous_id = params[:previous_id]
      activities = Helpdesk::Activity.freshest(current_account).activity_since(previous_id).permissible(current_user)
      render :partial => "ticket_note", :collection => activities
    rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "Error occoured in la"})
    end
  end
  
  def latest_summary
    render :partial => "summary"
  end

  protected
    def recent_activities(activity_id)
      if activity_id

        Helpdesk::Activity.freshest(current_account).activity_before(activity_id).permissible(current_user) unless activity_id == "0"
      else
        Helpdesk::Activity.freshest(current_account).permissible(current_user)
      end
    end
  private
    def load_items
      @items = recent_activities(params[:activity_id]).paginate(:page => params[:page], :per_page => 10)
    end
    
    def set_selected_tab
      @selected_tab = :dashboard
    end
end
