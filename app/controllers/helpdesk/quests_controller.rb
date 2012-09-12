class Helpdesk::QuestsController < ApplicationController
  before_filter :set_selected_tab
  before_filter { |c| c.requires_feature :gamification }
  
  def index
    @quests = scoper.paginate(:all, :page => params[:page], :per_page => 25)
    if request.xhr?
      render :partial => "quest", :collection => @quests
    end
  end

  def active
    ##need to fetch only locked quests for the agent.
    @quests = unachieved_scoper.find(:all, :limit => 2)
    render :layout => false
  end

  def unachieved
    @quests = unachieved_scoper.paginate(:all, :page => params[:page], :per_page => 25)
    if request.xhr?
      render :partial => "quest", :collection => @quests
    end
  end

  private
  	def scoper
  	  current_account.quests
  	end
  	
  	def unachieved_scoper
  	  scoper.available(current_user)
  	end

	  def set_selected_tab
      @selected_tab = :dashboard
    end

end
