class Helpdesk::CommonsController < ApplicationController

  before_filter :set_mobile, :only => [:group_agents]
  skip_before_filter :check_privilege

  def group_agents
  	group_id = params[:id]
    blank_value = !params[:blank_value].blank? ? params[:blank_value] : "..."
    @agents = current_account.agents.all(:include =>:user)
    @agents = AgentGroup.find(:all, :joins=>:user, :conditions => { :group_id =>group_id ,:users =>{:account_id =>current_account.id , :deleted => false } } ) unless group_id.nil?
    respond_to do |format|
      format.html {
        render :partial => "group_agents", :locals =>{ :blank_value => blank_value }
      }
      format.mobile {
        json = "["; sep=""
          @agents.each { |agent_group|
            user = agent_group.user
            #Removing the root node, so that it conforms to JSON REST API standards
            # 8..-2 will remove "{user:" and the last "}"
            json << sep + user.to_mob_json()[8..-2]; sep=","
          }
        render :json => json + "]"
      }
    end
  end

end
