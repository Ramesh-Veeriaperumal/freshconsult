class Helpdesk::CommonsController < ApplicationController

  before_filter :set_mobile, :only => [:group_agents]
  skip_before_filter :check_privilege, :verify_authenticity_token

  def group_agents
  	group_id = params[:id]
    assigned_agent = params[:agent]
    blank_value = !params[:blank_value].blank? ? params[:blank_value] : "..."
    @agents = if group_id.present?
      AgentGroup.where({ :group_id => group_id, :users => {:account_id => current_account.id , :deleted => false } }).joins(:user)
    else
      current_account.agents.includes(:user)
    end
    respond_to do |format|
      format.html {
        render :partial => "group_agents", :locals =>{ :blank_value => blank_value, :assigned_agent => assigned_agent }
      }
      format.mobile {
        array = []
          @agents.each { |agent_group|
            array << agent_group.user.to_mob_json(:root => false)
          }
        render :json => array
      }
    end
  end

end
