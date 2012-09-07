class Helpdesk::QuestsController < ApplicationController
    
  def achievements
    
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
  
end
