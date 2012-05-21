require 'rubygems'
require 'jira4r'
require 'json'

class Integrations::JiraIssue

	def initialize(username, password, installed_app, params)
			@jira = Jira4R::JiraTool.new(2, params['domain'])
			@jira.login(username, password)
            @installed_app = installed_app unless installed_app.blank?
            Rails.logger.debug "Initialized jira object :: " + @jira.inspect
	end

	def create(params)
		issue = Jira4R::V2::RemoteIssue.new
		issue.project = params['projectId']
		issue.type = params['issueTypeId']
		issue.summary = params['summary']
		issue.description = params['description']
		Rails.logger.debug "Sending request to create a new issue : #{issue.inspect}"
		resData = @jira.createIssue(issue)
		Rails.logger.debug "Received response for creating a new issue : #{resData.inspect}"
		params['remoteKey'] = resData.key unless resData.key.blank? 
		resData = update(params, resData)
		resData.to_json
	end

	def get_issue_types(params)
		jsonArray = Array.new
		issueTypes = @jira.getIssueTypes()
		Rails.logger.debug "Received response for fetching issue types : #{issueTypes.inspect}"
        issueTypes.each { |i_type|
          jsonArray.push 'typeId' => i_type.id, 'typeName' => i_type.name
        }
		resJson = {'types' => jsonArray}
		return resJson
	end

	def delete(params)
		@jira.deleteIssue(params['integrated_resource']['remote_integratable_id'])
	end

	def update(params, resData = nil)
        customId = customFieldChecker
        if(customId)
			customField = Jira4R::V2::RemoteFieldValue.new
            customField.id = customId
			customField.values = params['ticketData']
			resData = @jira.updateIssue(params['remoteKey'], [customField])	
			Rails.logger.debug "Received response for updating a jira issue : #{resData.inspect}"
			comment = false
		else
			issueId = params['remoteKey']
			commentResponse = addCommentToJira(issueId, params['ticketData'])
			Rails.logger.debug "Received response for adding a comment to jira : #{commentResponse.inspect}"
			comment = true
		end
		if(comment == true && commentResponse != nil)
			resData = nil
		end	
		resData
	end

    def delete_custom_field
        @installed_app[:configs][:inputs]['customFieldId'] = nil
        @installed_app.save!
    end

    def jira_serverinfo
        server_info = @jira.getServerInfo().version
        Rails.logger.debug "Received response for getting server info : #{server_info.inspect}"
        return server_info
    end

    private
	def getCustomFieldId
		customData = @jira.getCustomFields()
		Rails.logger.debug "Received response for getting custom fields : #{customData.inspect}"
		customData.each do |customField|
			if(customField.name == "Freshdesk Tickets")
				return customField.id
			end
		end
		return
	end

	def addCommentToJira(issueId, ticketData)
		jiraComment = Jira4R::V2::RemoteComment.new
		jiraComment.body = ticketData
		Rails.logger.debug "Sending request get a jira comment object : #{jiraComment.inspect}"
		@jira.addComment(issueId, jiraComment)
	end

    def customFieldChecker 
        if @installed_app.configs_customFieldId
            return @installed_app.configs_customFieldId
        else
            return populate_custom_field
        end
        return
    end

    def populate_custom_field 
        custom_field_id = getCustomFieldId
        unless custom_field_id.blank?
            @installed_app[:configs][:inputs]['customFieldId'] = custom_field_id
            @installed_app.save!
            return custom_field_id
        end
        return
    end
	
end
