require 'rubygems'
require 'jira4r'

class Integrations::JiraIssueController < ApplicationController

	include Integrations::JiraSystem

	before_filter :getJiraObject
	
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
			resData = @jiraObj.update(params)
			params['integrated_resource']['account'] = current_account
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
		password = Integrations::AppsUtil.get_decrypted_value(@installed_app.configs_password)
		@jiraObj = Integrations::JiraIssue.new(username, password, @installed_app, params)

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

end
