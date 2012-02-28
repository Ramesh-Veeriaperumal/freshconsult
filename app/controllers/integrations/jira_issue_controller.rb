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
			render :json => {:error=> "#{msg}"}
		end
	end

	def create
		Rails.logger.debug "Creating Jira Issues  " + params.inspect
		begin
			resData = $jiraObj.create(params)
			installed_app = Integrations::InstalledApplication.find(:all, :include=>:application, 
                  :conditions => {:applications => {:name => "jira"}, :account_id => current_account})
            custom_field_id = installed_app[0].configs[:inputs]['customFieldId']
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
			resData = $jiraObj.update(params)
			#resData should be checked for errors ---------------
			installed_app = Integrations::InstalledApplication.find(:all, :include=>:application, 
                  :conditions => {:applications => {:name => "jira"}, :account_id => current_account})
            custom_field_id = installed_app[0].configs[:inputs]['customFieldId']
            if params['updateType'] != "unlink"
				params['integrated_resource']['remote_integratable_id'] = params['remoteKey']
				params['integrated_resource']['account'] = current_account
				newIntegratedResource = Integrations::IntegratedResource.createResource(params)
				newIntegratedResource["custom_field"]=custom_field_id unless custom_field_id.blank?
				render :json => newIntegratedResource
			else
				render :json => {:status=>'Issue Unlinked'}
			end

		rescue Exception => msg
			#puts "Error linking the ticket to the jira issue ( #{msg})"
			render :json => {:error=> "#{msg}"}
			#if customid field not available exception occurs, do some stuff to delete the customfield id and add comment
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
			render :json => {:error=> "#{msg}"}
		end
	end

	def getCustomFieldId
		begin
			customFieldId = $jiraObj.getCustomFieldId();
			render :json => {:customFieldId=> "#{customFieldId}"}
		rescue Exception => msg
			puts "Error fetching custom fields from Jira ( #{msg})"
			render :json => {:error=> "#{msg}"}
		end
	end

	def getJiraObject
		installed_app = Integrations::InstalledApplication.find(:all, :include=>:application, 
                  :conditions => {:applications => {:name => "jira"}, :account_id => current_account})
		username = get_jira_username(installed_app)
		password = get_jira_password(installed_app)
		$jiraObj = Integrations::JiraIssue.new(username, password, installed_app, params)

	end

	def reload_custom_field
		begin
			$jiraObj.delete_custom_field
			create
		rescue Exception => msg
			puts "Error reloading custom field ( #{msg})"
			render :json => {:error=> "#{msg}"}
		end

	end

end
