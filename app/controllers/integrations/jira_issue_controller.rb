require 'rubygems'
require 'jira4r'

class Integrations::JiraIssueController < ApplicationController

	include Integrations::JiraSystem

	before_filter :getJiraObject
	
	def show
		Rails.logger.debug "Fetching issue types from Jira  " + params.inspect
		begin
			resJson = $jiraObj.show(params)
			render :json => resJson
		rescue Exception => msg
			puts "Fetching Issue Types from Jira failed ( #{msg})"
			render :json => {:status=> "#{msg}"}
		end
	end

	def create
		Rails.logger.debug "Creating Jira Issues  " + params.inspect
		begin
			resData = $jiraObj.create(params)
			unless resData.blank?
				resJson = JSON.parse(resData)
				params['integrated_resource']['remote_integratable_id'] = resJson['key']
				params['integrated_resource']['account'] = current_account
				newIntegratedResource = Integrations::IntegratedResource.createResource(params)
				render :json => newIntegratedResource
			end
		rescue Exception => msg
			puts "Error exporting ticket to jira issue ( #{msg})"
			render :json => {:status=>:error}
		end
	end

	def update
		Rails.logger.debug "Updating Jira Issues  " + params.inspect
		begin
			resData = $jiraObj.update(params)
			params['integrated_resource']['remote_integratable_id'] = params['remoteKey']
			params['integrated_resource']['account'] = current_account
			newIntegratedResource = Integrations::IntegratedResource.createResource(params)
			render :json => newIntegratedResource
		rescue Exception => msg
			#puts "Error linking the ticket to the jira issue ( #{msg})"
			render :json => {:status=>:error}
		end
	end

	def destroy
		Rails.logger.debug "Deleting Jira Issues  " + params.inspect
		begin
			params['integrated_resource']['account'] = current_account
			$jiraObj.delete(params)
			remote_integratable_id = params['integrated_resource']['remote_integratable_id']
			remoteIdArray = Integrations::IntegratedResource.find(:all, :joins=>"INNER JOIN installed_applications ON integrated_resources.installed_application_id=installed_applications.id", 
                     :conditions=>['integrated_resources.remote_integratable_id=? and installed_applications.account_id=?',remote_integratable_id,current_account])
                     puts (params['integrated_resources'])
			remoteIdArray.each do|remoteId|
				params['integrated_resource']['id'] = remoteId.id
				$status = Integrations::IntegratedResource.deleteResource(params)
			end
			render :json => {:status=>$status}
		rescue Exception => msg
			puts "Error deleting jira issue ( #{msg})"
			render :json => {:status=>:error}
		end
	end

	def getCustomFieldId
		begin
			customFieldId = $jiraObj.getCustomFieldId();
			render :json => {:customFieldId=> "#{customFieldId}"}
		rescue Exception => msg
			puts "Error fetching custom fields from Jira ( #{msg})"
			render :json => {:status=>:error}
		end
	end

	def getJiraObject
		installed_app = Integrations::InstalledApplication.find(:all, :joins=>:application, 
                  :conditions => {:applications => {:name => "jira"}, :account_id => current_account})
		username = get_jira_username(installed_app)
		password = get_jira_password(installed_app)
		$jiraObj = Integrations::JiraIssue.new(username, password, params)
	end

end
