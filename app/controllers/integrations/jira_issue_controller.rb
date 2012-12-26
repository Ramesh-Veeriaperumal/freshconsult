require 'rubygems'
require 'jira4r'

class Integrations::JiraIssueController < ApplicationController
	include Integrations::Constants
  include RedisKeys

  skip_before_filter :check_privilege, :only => [:notify]
	before_filter :validate_request, :only => [:notify, :register] # TODO Needs to be replaced with OAuth authentication.
  before_filter :getJiraObject, :except => [:notify, :register]	

	def get_issue_types
		begin
			resJson = @jiraObj.get_issue_types(params)
			render :json => resJson
		rescue Exception => e
			Rails.logger.error "Fetching Issue Types from Jira failed. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
			render :json => {:error=> "#{e}"}
		end
	end

	def create
		begin
			resData = @jiraObj.create(params)
      custom_field_id = @installed_app.configs[:inputs]['customFieldId']
			unless resData.blank?
				resJson = JSON.parse(resData)
				Rails.logger.debug "Response received for creating a new issue in Jira :: " + resJson.inspect
				params['integrated_resource']['remote_integratable_id'] = resJson['key']
				params['integrated_resource']['account'] = current_account
				newIntegratedResource = Integrations::IntegratedResource.createResource(params)
				newIntegratedResource["custom_field"]=custom_field_id unless custom_field_id.blank?
				Rails.logger.debug "Adding the new issue to integrated_resources  " + newIntegratedResource.inspect
				render :json => newIntegratedResource
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
			resData = @jiraObj.update(params)
      custom_field_id = @installed_app.configs[:inputs]['customFieldId']
			params['integrated_resource']['remote_integratable_id'] = params['remoteKey']
			params['integrated_resource']['account'] = current_account
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
			params['integrated_resource']['account'] = current_account
			if @installed_app.configs_customFieldId
				resData = @jiraObj.update(params)
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
			params['integrated_resource']['account'] = current_account
			@jiraObj.delete(params)
			status = Integrations::IntegratedResource.delete_resource_by_remote_integratable_id(params)
			render :json => {:status=>status}
		rescue Exception => e
			Rails.logger.error "Error deleting jira issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
			render :json => {:error=> "#{e}"}
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
		@installed_app = Integrations::InstalledApplication.find(:first, :include=>:application, 
                  :conditions => {:applications => {:name => "jira"}, :account_id => current_account})
         
		username = @installed_app.configs_username
		password = @installed_app.configsdecrypt_password
		@jiraObj = Integrations::JiraIssue.new(username, password, @installed_app, @installed_app.configs_domain)

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
end
