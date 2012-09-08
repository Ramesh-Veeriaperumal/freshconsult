class Helpdesk::QuestsController < ApplicationController
  before_filter :set_selected_tab
    
  def achievements
    @active_quest = scoper.find(:all)
  end

  def active
    ##need to fetch only locked quests for the agent.
    @active_quest = scoper.find(:all, :limit => 3)
    render :layout => false
  end

  private
  	def scoper
		current_account.quests
  	end

	def set_selected_tab
      @selected_tab = :dashboard
    end

end
