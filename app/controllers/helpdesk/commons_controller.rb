class Helpdesk::CommonsController < ApplicationController

  before_filter :set_mobile, :only => [:group_agents]
  skip_before_filter :check_privilege, :verify_authenticity_token

  PHONE_REGEX = /.+\((.+)\)/
  TWITTER_REGEX = /@(.+)/

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
  
  def fetch_company_by_name
    company = current_account.companies.find_by_name(params["name"])
    respond_to do |format|
      if company
        format.json { render :json => company.to_json }
      else
        format.json { render :json => {:error => "Record not found" }}
      end
    end
  end

  def user_companies
    to_ret = false
    if current_user && (current_user.agent? || current_user.contractor?)
      user = nil
      case true
        when (params[:email] =~ EMAIL_REGEX).present?
          email = $1
          user_email = current_account.user_emails.find_by_email(email)
          user = user_email.user if user_email
        when (params[:email] =~ PHONE_REGEX).present?
          phone = $1.strip
          user = current_account.users.where(["phone like ? or mobile like ?", "%#{phone}%", "%#{phone}%"]).first
        when (params[:email] =~ TWITTER_REGEX).present?
          twitter_id = $1
          user = current_account.users.find_by_twitter_id(twitter_id)
      end
      to_ret = user.companies.sorted.collect { |c| [c.name, c.id] } if (user && user.companies.present?)
    end
    render :json => to_ret
  end
end
