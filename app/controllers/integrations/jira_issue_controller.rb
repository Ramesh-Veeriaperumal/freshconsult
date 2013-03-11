require 'rubygems'
require 'jira4r'

class Integrations::JiraIssueController < ApplicationController
  include Integrations::Constants
  include Integrations::AppsUtil
  include RedisKeys

  before_filter :validate_request, :only => [:notify, :register] # TODO Needs to be replaced with OAuth authentication.
  before_filter :getJiraObject, :except => [:notify, :register]
  before_filter :populate_server_password, :only => [:create,:destroy,:update,:unlink,:get_all_mandatory_fields]
  before_filter :authenticated_agent_check 
  
  def create
    begin
      res_data = @jiraObj.create(params, request)
      response.headers.merge!(res_data.delete('x-headers')) if res_data['x-headers'].present?
      custom_field_id = @installed_app.configs[:inputs]['customFieldId']
      unless res_data.blank?
        if(res_data["errorMessages"])
          render :json => {:error=> "Exception:"+res_data["errors"].values.join(",")}
        else 
        params['integrated_resource']={}
        params['integrated_resource']['remote_integratable_id'] = params[:remote_key]
        params['integrated_resource']['account'] = current_account
        params['integrated_resource']['local_integratable_id'] = params[:local_integratable_id]
        params['integrated_resource']['local_integratable_type'] = params[:local_integratable_type]
        newIntegratedResource = Integrations::IntegratedResource.createResource(params)
        newIntegratedResource["custom_field"]=custom_field_id unless custom_field_id.blank?
        render :json => newIntegratedResource
       end      
      end
    rescue Exception => e
      Rails.logger.error "Error exporting ticket to jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      if e.to_s.include? 'Exception: Custom field ID'
        reload_custom_field
      else
        render :json => {:error=> "#{e}"}
      end

    end
  end

  def update
    begin
      res_data = @jiraObj.update(params, request)
      custom_field_id = @installed_app.configs[:inputs]['customFieldId']
      params['integrated_resource']={}
      params['integrated_resource']['remote_integratable_id'] = params[:remote_key]
      params['integrated_resource']['account'] = current_account
      params['integrated_resource']['local_integratable_id'] = params[:local_integratable_id]
      params['integrated_resource']['local_integratable_type'] = params[:local_integratable_type]
      newIntegratedResource = Integrations::IntegratedResource.createResource(params)
      newIntegratedResource["custom_field"]=custom_field_id unless custom_field_id.blank?
      render :json => newIntegratedResource
    rescue Exception => e
      Rails.logger.error "Error linking the ticket to the jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      render :json => {:error=> "#{e}"}
    end
  end

  def unlink
    begin
      params['integrated_resource']={}
      params['integrated_resource']['id']=params[:id]
      params['integrated_resource']['account'] = current_account
      if @installed_app.configs_customFieldId
        res_data = @jiraObj.update(params, request)
      end
      Integrations::IntegratedResource.deleteResource(params)
      render :json => {:status=> :success}
    rescue Exception => e
      Rails.logger.error "Error unlinking the ticket from the jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      render :json => {:error=> "#{e}"}
    end
  end

  def destroy
    begin
      params['integrated_resource']={}
      params['integrated_resource']['remote_integratable_id'] = params[:remote_integratable_id]
      params['integrated_resource']['account'] = current_account
      res_data = @jiraObj.delete(params, request)
      if(res_data[:status]==204)
        status = Integrations::IntegratedResource.delete_resource_by_remote_integratable_id(params)
        render :json => {:status=>status}
      else
        render :json => {:error=> "Exception:#{JSON.parse(resData[:text])['errorMessages'].to_s}"}
      end
    rescue Exception => e
      Rails.logger.error "Error deleting jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      render :json => {:error=> "#{e}"}
    end
  end

  def get_all_mandatory_fields
    begin
      res_data = @jiraObj.get_all_mandatory_fields_for_project_and_issuetype(params, request)
      render :json => res_data
    rescue Exception => e
      render :json => {:error => "#{e}"}
    end
  end

  def getCustomFieldId
    begin
      customFieldId = @jiraObj.getCustomFieldId();
      render :json => {:customFieldId=> "#{customFieldId}"}
    rescue Exception => e
      Rails.logger.error "Error fetching custom fields from Jira. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      render :json => {:error=> "#{e}"}
    end
  end

  def getJiraObject
    @installed_app = Integrations::InstalledApplication.find(:first, :include=>:application,:conditions => {:applications => {:name => "jira"}, :account_id => current_account})
    @jiraObj = Integrations::JiraIssue.new(@installed_app)
  end

  def reload_custom_field
    begin
      @jiraObj.delete_custom_field
      create
    rescue Exception => e
      Rails.logger.error "Error reloading custom field. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      render :json => {:error=> "#{e}"}
    end

  end

  def register
    cert_file  = "#{RAILS_ROOT}/integrations/atlassian-jira/#{Rails.env}-register.xml"
    respond_to do |format|
      format.xml do
        render :xml => File.read(cert_file)
      end
    end
    #@jiraObj.register_webhooks(current_portal.host)
  end

  def notify
    if params[:id] == "remote_app_started"
      # TODO: Logic to fetch the jira public key and preserve it for later the oauth 2-legged signature verification.
    else
      jira_webhook = Integrations::JiraWebhook.new(params)
      if @installed_app.blank?
        Rails.logger.log "Linked ticket not found for remote JIRA app with params #{params.inspect}"
      else
        jira_webhook.update_local(@installed_app)
      end
    end
  end

  def fetch_jira_projects_issues
    resData ={}
    resData[:res_projects] = @jiraObj.fetch_jira_projects(request)
    resData[:res_issues] = @jiraObj.fetch_jira_issues(request)
    render :json => resData
  end

  private
  def validate_request
    jira_ip = request.remote_ip
    Rails.logger.debug "Validate ip headers #{request.headers['HTTP_AUTHORIZATION']} #{jira_ip}"
    matches = /207\.223\.247\.(\d\d?\d?)/.match(jira_ip)
    if (!matches.blank? and matches.size == 2)
      last_octet = matches[1].to_i
      if last_octet >= 10 or last_octet <= 52
        header = request.headers['HTTP_AUTHORIZATION']
        con_key_mathces = /OAuth oauth_consumer_key="([^"]*)".*/.match(header)
        unless con_key_mathces.blank? # TODO: Logic to fetch the jira public key and preserve it for later the oauth 2-legged signature verification.
          jira_url = con_key_mathces[1]
          remote_integratable_id = params["issue"]["key"];
          # TODO:  Costly query.  Needs to revisit and index the integrated_resources table and/or split the quries.
          @installed_app = Integrations::InstalledApplication.with_name(APP_NAMES[:jira]).first(:select=>["installed_applications.*, integrated_resources.*"],
                                                                                                :joins=>"INNER JOIN integrated_resources ON integrated_resources.installed_application_id=installed_applications.id",
                                                                                                :conditions=>["integrated_resources.remote_integratable_id=? and configs like ?", remote_integratable_id, "%#{jira_url}%"])
          unless @installed_app.blank?
            local_integratable_id = @installed_app.local_integratable_id
            account_id = @installed_app.account_id
            recently_updated_by_fd = get_key(INTEGRATIONS_JIRA_NOTIFICATION % {:account_id=>account_id, :local_integratable_id=>local_integratable_id, :remote_integratable_id=>remote_integratable_id})
            if recently_updated_by_fd # If JIRA has been update recently with same params then ignore that event.
              @installed_app = nil
              Rails.logger.log("Recently freshdesk updated JIRA with same params.  So ignoring the event.")
            end
          end
        end
        return
      end
    end
    render :text => "Unauthorized IP", :status => 401 unless jira_ip == "61.12.112.69"
  end

  def populate_server_password
    if params[:use_server_password].present?
      params[:username] = @installed_app.configs_username if params[:username]
      params[:password] = @installed_app.configsdecrypt_password
    end
  end

  def authenticated_agent_check
    render :status => 401 if current_user.blank? || current_user.agent.blank?
  end
end
