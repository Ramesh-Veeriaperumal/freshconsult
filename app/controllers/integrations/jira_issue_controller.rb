require 'rubygems'
require 'jira4r'

class Integrations::JiraIssueController < ApplicationController

	include Integrations::JiraSystem

	before_filter :getJiraObject
	
	def get_issue_types
		Rails.logger.debug "Fetching issue types from Jira  " + params.inspect
		begin
			resJson = @jiraObj.get_issue_types(params)
			render :json => resJson
		rescue Exception => msg
			puts "Fetching Issue Types from Jira failed ( #{msg})"
			render :json => {:error=> "#{msg}"}
		end
	end

	def create
		Rails.logger.debug "Creating Jira Issues  " + params.inspect
		begin
			resData = @jiraObj.create(params)
            custom_field_id = @installed_app.configs[:inputs]['customFieldId']
			unless resData.blank?
				resJson = JSON.parse(resData)
				params['integrated_resource']['remote_integratable_id'] = resJson['key']
				params['integrated_resource']['account'] = current_account
				newIntegratedResource = Integrations::IntegratedResource.createResource(params)
				newIntegratedResource["custom_field"]=custom_field_id unless custom_field_id.blank?
				render :json => newIntegratedResource
			end
		rescue Exception => msg
			puts "Error exporting ticket to jira issue ( #{msg})"
			if msg.to_s.include? 'Exception: Custom field ID'
				reload_custom_field
			else
				render :json => {:error=> "#{msg}"}	
			end
			
		end
	end

	def update
		Rails.logger.debug "Updating Jira Issues  " + params.inspect
		begin
			resData = @jiraObj.update(params)
            custom_field_id = @installed_app.configs[:inputs]['customFieldId']
				params['integrated_resource']['remote_integratable_id'] = params['remoteKey']
				params['integrated_resource']['account'] = current_account
				newIntegratedResource = Integrations::IntegratedResource.createResource(params)
				newIntegratedResource["custom_field"]=custom_field_id unless custom_field_id.blank?
				render :json => newIntegratedResource
		rescue Exception => msg
			puts "Error linking the ticket to the jira issue ( #{msg})"
			render :json => {:error=> "#{msg}"}
		end
	end

	def unlink
		Rails.logger.debug "Unlinking Jira Issues  " + params.inspect
		begin
			resData = @jiraObj.update(params)
			params['integrated_resource']['account'] = current_account
			Integrations::IntegratedResource.deleteResource(params)
           	render :json => {:status=> :success}
		rescue Exception => msg
			puts "Error unlinking the ticket from the jira issue ( #{msg})"
			render :json => {:error=> "#{msg}"}
		end
	end

	def destroy
		Rails.logger.debug "Deleting Jira Issues  " + params.inspect
		begin
			params['integrated_resource']['account'] = current_account
			@jiraObj.delete(params)
			status = Integrations::IntegratedResource.delete_resource_by_remote_integratable_id(params)
			render :json => {:status=>status}
		rescue Exception => msg
			puts "Error deleting jira issue ( #{msg})"
			render :json => {:error=> "#{msg}"}
		end
	end

	def getCustomFieldId
		begin
			customFieldId = @jiraObj.getCustomFieldId();
			render :json => {:customFieldId=> "#{customFieldId}"}
		rescue Exception => msg
			puts "Error fetching custom fields from Jira ( #{msg})"
			render :json => {:error=> "#{msg}"}
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
		rescue Exception => msg
			puts "Error reloading custom field ( #{msg})"
			render :json => {:error=> "#{msg}"}
		end

	end

end
