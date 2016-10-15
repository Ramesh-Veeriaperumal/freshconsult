class Helpdesk::CommonsController < ApplicationController

  before_filter :set_mobile, :only => [:group_agents]
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :check_privilege, :only => [:fetch_company_by_name, :status_groups]

  before_filter :only => [:group_agents, :user_companies] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  before_filter :group_agent_fields_editable?, :only => [:group_agents]

  PHONE_REGEX = /.+\((.+)\)/
  TWITTER_REGEX = /@(.+)/

  include AccountConstants

  def group_agents
  	group_id = params[:id]
    assigned_agent = params[:agent]
    blank_value = !params[:blank_value].blank? ? params[:blank_value] : "..."
    @agents = if group_id.present?
      current_account.agent_groups.where({:group_id => group_id, :users => {:account_id => current_account.id, :deleted => false} }).preload(:user).joins(:user).order("users.name")
    else
      current_account.agents.includes(:user)
    end
    allow_none = params[:allow_none].blank? ? false : true
    respond_to do |format|
      format.html {
        render :partial => "group_agents", :locals =>{ :blank_value => blank_value, :assigned_agent => assigned_agent, :allow_none => allow_none }
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

  def status_groups
    if params[:status_id] and current_account.features?(:shared_ownership) 
      assigned_group_id = params[:group_id]
      status = current_account.ticket_status_values_from_cache.find{|s| s.status_id == params[:status_id].to_i and !s.is_default}
      group_ids = status.try(:group_ids)
      @groups = current_account.groups_from_cache.select { |g| group_ids.include?(g.id) } if group_ids.present?
    end
    respond_to do |format|
      format.html {
        blank_value = "..."
        render :partial => "status_groups", :locals =>{ :blank_value => blank_value, :assigned_group_id => assigned_group_id }
      }
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
      to_ret = user.companies.sorted.collect { |c| [c.name, c.id] } if (user &&
               user.companies.length > 1)
    end
    render :json => to_ret
  end

  private

    def group_agent_fields_editable?
      if current_user.nil? || current_user.customer?
        ticket_fields = current_account.ticket_fields_from_cache
        group_field = ticket_fields.find { |tf| tf.name == "group"}
        agent_field = ticket_fields.find { |tf| tf.name == "agent"}
        access_denied if !group_field.editable_in_portal || !agent_field.editable_in_portal
      end
    end
end
