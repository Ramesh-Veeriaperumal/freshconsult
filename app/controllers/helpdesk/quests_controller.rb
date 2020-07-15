class Helpdesk::QuestsController < ApplicationController
  before_filter :set_selected_tab
  before_filter { |c| c.requires_this_feature :gamification }
  
  helper Helpdesk::QuestsHelper

  def index
    @quests = scoper.paginate(:page => params[:page], :per_page => 25)
    @user_acheived_quests = current_user.achieved_quests.select(:quest_id).where("quest_id in (#{@quests.map(&:id).join(',')})").map(&:quest_id)
    if request.xhr? and !request.headers['X-PJAX']
      render :partial => "quest", :collection => @quests
    end
  end

  def active
    ##need to fetch only locked quests for the agent.
    #@quests = unachieved_scoper.find(:all, :limit => 2)
    render :layout => false
  end

  def unachieved
    @quests = unachieved_scoper.paginate(:page => params[:page], :per_page => 25)
    if request.xhr? and !request.headers['X-PJAX']
      render :partial => "quest", :collection => @quests
    end
  end

  private
  	def scoper
      current_account.features?(:forums) ? current_account.quests :  current_account.quests.where("category != ?",Gamification::Quests::Constants::GAME_TYPE_KEYS_BY_TOKEN[:forum])
    end
  	
  	def unachieved_scoper
  	  scoper.available(current_user)
  	end

	  def set_selected_tab
      @selected_tab = :dashboard
    end

end
