require 'rubygems'
require 'jira4r'

class Integrations::JiraIssueController < ApplicationController
  include Integrations::Constants
  include Integrations::AppsUtil
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:notify]
  before_filter :validate_request, :only => [:notify] # TODO Needs to be replaced with OAuth authentication.
  before_filter :jira_object, :except => [:notify]
  before_filter :authenticated_agent_check,:except => [:notify]

  def create
    change_display_id_to_ticket_id
    begin
      res_data = @jira_obj.create(params)
      render :json => res_data
    rescue Exception => e
      Rails.logger.error "Error exporting ticket to jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e,{:description => "Error occoured in fetching project and issues"})
      render :json => {:errorMessages => ["Error exporting ticket to jira issue"]},:status => 404
    end
  end

  def update
    change_display_id_to_ticket_id
    begin
      res_data = @jira_obj.link_issue(params)
      render :json => res_data
    rescue Exception => e
      Rails.logger.error "Error linking the ticket to the jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e,{:description => "Error linking the ticket to the jira issue"})
      render :json => {:errorMessages=> ["Error linking the ticket to the jira issue"]},:status => 404
    end
  end

  def unlink
    begin
      res_data = @jira_obj.unlink_issue(params)
      render :json => res_data
    rescue Exception => e
      Rails.logger.error "Error unlinking the ticket from the jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e,{:description => "Error unlinking the ticket from the jira issue"})
      render :json => {:errorMessages=> ["Error unlinking the ticket from the jira issue"]},:status => 404
    end
  end

  def destroy
    begin
      res_data = @jira_obj.delete(params)
      render :json => res_data
    rescue Exception => e
      Rails.logger.error "Error deleting jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e,{:description => "Error unlinking the ticket from the jira issue"})
      render :json => {:errorMessages=> ["Error unlinking the ticket from the jira issue"]},:status => 404
    end
  end

  def fetch_jira_projects_issues
    begin
     render :json => @jira_obj.fetch_jira_projects_issues
    rescue Exception => e
     Rails.logger.error "Error fetching the project and issues"
     NewRelic::Agent.notice_error(e,{:description => "Error occoured in fetching project and issues"})
     render :json => {:errorMessages=> ["Unable to fetch Projects and issues"]},:status => 404
    end
  end

  def notify
    if params[:webhookEvent] == "remote_app_started"
      # TODO: Logic to fetch the jira public key and preserve it for later the oauth 2-legged signature verification.
    else
      jira_webhook = Integrations::JiraWebhook.new(params)
      if @installed_app.blank?
        Rails.logger.info "Linked ticket not found for remote JIRA app"
      else
        jira_webhook.update_local(@installed_app,@selected_key)
      end
    end
    render :nothing => true
  end

  private

  def issue_changes
    @selected_key = params["changelog"].present? && params["changelog"]["items"].detect{ |changes| changes["field"] == "Key"}
  end


  def change_display_id_to_ticket_id
     if params[:local_integratable_display_id].present?
      display_id = params[:local_integratable_display_id]
      ticket = current_account.tickets.find_by_display_id(display_id)
      params[:local_integratable_id] = ticket.id if ticket
    end
  end

  def validate_request
     unless valid_auth_key?(params["auth_key"])
       render text: 'Unauthorized Access'.freeze, status: 401
       return
     end
     old_issue_id = issue_changes && @selected_key["fromString"]
     if params["issue"] && (old_issue_id || params["issue"]["key"])
       remote_integratable_id = old_issue_id || params["issue"]["key"]
       auth_key = params["auth_key"]
       # TODO:  Costly query.  Needs to revisit and index the integrated_resources table and/or split the quries.
       @installed_app = Integrations::InstalledApplication.with_name(APP_NAMES[:jira]).first(:select=>["installed_applications.*,integrated_resources.local_integratable_id,integrated_resources.local_integratable_type,integrated_resources.remote_integratable_id"],
                                                                                             :joins=>"INNER JOIN integrated_resources ON integrated_resources.installed_application_id=installed_applications.id",
                                                                                             :conditions=>["integrated_resources.remote_integratable_id=? and configs like ?", remote_integratable_id, "%#{auth_key}%"])
       if @installed_app && @installed_app.local_integratable_type == "Helpdesk::Ticket"
            local_integratable_id = @installed_app.local_integratable_id
            account_id = @installed_app.account_id
            id = params["comment"]? params["comment"]["id"] : Digest::SHA512.hexdigest("@")
            recently_updated_by_fd = get_integ_redis_key(INTEGRATIONS_JIRA_NOTIFICATION % {:account_id=> account_id, :local_integratable_id=> local_integratable_id, :remote_integratable_id=> remote_integratable_id, :comment_id => id})
            if recently_updated_by_fd || (params[:comment] && (params[:comment]["body"] =~ /Note added by .* in Freshdesk:/  || params[:comment]["body"] =~/Freshdesk ticket status changed to :/)) # If JIRA has been update recently with same params then ignore that event.
              remove_integ_redis_key(INTEGRATIONS_JIRA_NOTIFICATION % {:account_id=>account_id, :local_integratable_id=>local_integratable_id, :remote_integratable_id=>remote_integratable_id, :comment_id => id})
              @installed_app = nil
            end
       elsif @installed_app && @installed_app.local_integratable_type == "Helpdesk::ArchiveTicket"
        integrated_resource = Integrations::IntegratedResource.find_by_local_integratable_id_and_local_integratable_type(@installed_app.local_integratable_id,"Helpdesk::ArchiveTicket")
        if integrated_resource
          archive_ticket = integrated_resource.local_integratable
          if archive_ticket && allow_updates_from_jira?
            ticket = archive_ticket.ticket || create_ticket(archive_ticket)
            modify_integrated_resource(ticket,integrated_resource)
          end
        end
       end
       return
     end
     render text: 'Bad Request'.freeze, status: 400
  end

  def valid_auth_key?(auth_key)
    auth_key.try(:strip).present?
  end

  def authenticated_agent_check
    render :status => 401 if current_user.blank? || !current_user.agent?
  end

  def jira_object
    @installed_app = Integrations::InstalledApplication.includes(:application).where(applications: { name: 'jira' }, account_id: current_account).first
    @jira_obj = Integrations::JiraIssue.new(@installed_app)
  end

  def modify_integrated_resource(ticket,integrated_resource)
    integrated_resource = Integrations::IntegratedResource.find(integrated_resource.id)
    integrated_resource.update_attributes({:local_integratable_type => "Helpdesk::Ticket", :local_integratable_id => ticket.id }) if integrated_resource
  end

  def create_ticket(archive_ticket)
    ticket = Helpdesk::Ticket.new(
          :requester_id => archive_ticket.requester_id,
          :subject => archive_ticket.subject,
          :ticket_body_attributes => {
            :description => archive_ticket.description
    })
    ticket.build_archive_child(:archive_ticket_id => archive_ticket.id) if archive_ticket
    ticket.save_ticket
    ticket
  end

  def allow_updates_from_jira?
    (@installed_app.configs_jira_comment_sync != 'none' && Integrations::JiraWebhook::ALLOWED_JIRA_EVENTS[1..2].include?(params['webhookEvent'])) || (@installed_app.configs_jira_status_sync != 'none' && Integrations::JiraWebhook::ALLOWED_JIRA_EVENTS[0] == params['webhookEvent'])
  end
end
