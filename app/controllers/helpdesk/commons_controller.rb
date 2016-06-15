class Helpdesk::CommonsController < ApplicationController

  before_filter :set_mobile, :only => [:group_agents]
  skip_before_filter :check_privilege, :verify_authenticity_token

  include AccountConstants

  def group_agents
  	group_id = params[:id]
    assigned_agent = params[:agent]
    blank_value = !params[:blank_value].blank? ? params[:blank_value] : "..."
    @agents = if group_id.present?
      AgentGroup.where({ :group_id => group_id, :users => {:account_id => current_account.id , :deleted => false } }).joins(:user).order("users.name")
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

  def user_companies
    to_ret = false
    if current_user && (current_user.agent? || current_user.contractor?)
      if params[:email] =~ EMAIL_REGEX
        email = $1
        user_email = current_account.user_emails.find_by_email(email)
        user = user_email.user if user_email
        to_ret = user.companies.sorted.collect { |c| [c.name, c.id] } if (user && user.companies.present?)
      end
    end
    render :json => to_ret
  end
end
