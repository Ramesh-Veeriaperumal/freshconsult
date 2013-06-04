require 'rubygems'
require 'jira4r'

class Integrations::JiraIssueController < ApplicationController
  include Integrations::Constants
  include Integrations::AppsUtil
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  before_filter :validate_request, :only => [:notify] # TODO Needs to be replaced with OAuth authentication.
  before_filter :jira_object, :except => [:notify]
  before_filter :authenticated_agent_check,:except => [:notify]
  
  def create
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
    Rails.logger.info "#{params.inspect}"
    if params[:webhookEvent] == "remote_app_started"
      # TODO: Logic to fetch the jira public key and preserve it for later the oauth 2-legged signature verification.
    else
      jira_webhook = Integrations::JiraWebhook.new(params)
      if @installed_app.blank?
        Rails.logger.info "Linked ticket not found for remote JIRA app with params #{params.inspect}"
      else
        jira_webhook.update_local(@installed_app)
      end
    end
    render :nothing => true
  end

  private

  def validate_request
     if(params["issue"] && params["issue"]["key"] && params["auth_key"])
       remote_integratable_id = params["issue"]["key"]
       auth_key = params["auth_key"]
       # TODO:  Costly query.  Needs to revisit and index the integrated_resources table and/or split the quries.
       @installed_app = Integrations::InstalledApplication.with_name(APP_NAMES[:jira]).first(:select=>["installed_applications.*,integrated_resources.local_integratable_id,integrated_resources.remote_integratable_id"],
                                                                                             :joins=>"INNER JOIN integrated_resources ON integrated_resources.installed_application_id=installed_applications.id",
                                                                                             :conditions=>["integrated_resources.remote_integratable_id=? and configs like ?", remote_integratable_id, "%#{auth_key}%"])
       unless @installed_app.blank?
            local_integratable_id = @installed_app.local_integratable_id
            account_id = @installed_app.account_id
            recently_updated_by_fd = get_integ_redis_key(INTEGRATIONS_JIRA_NOTIFICATION % {:account_id=>account_id, :local_integratable_id=>local_integratable_id, :remote_integratable_id=>remote_integratable_id})
            if recently_updated_by_fd # If JIRA has been update recently with same params then ignore that event.
              remove_integ_redis_key(INTEGRATIONS_JIRA_NOTIFICATION % {:account_id=>account_id, :local_integratable_id=>local_integratable_id, :remote_integratable_id=>remote_integratable_id})
              @installed_app = nil
              Rails.logger.info("Recently freshdesk updated JIRA with same params. So ignoring the event.")
            end
       end
       return
     end
     render :text => "Unauthorized Access", :status => 401 
  end

  def authenticated_agent_check
    render :status => 401 if current_user.blank? || current_user.agent.blank?
  end

  def jira_object
    @installed_app = Integrations::InstalledApplication.find(:first, :include=>:application,:conditions => {:applications => {:name => "jira"}, :account_id => current_account})
    @jira_obj = Integrations::JiraIssue.new(@installed_app)
  end
end
