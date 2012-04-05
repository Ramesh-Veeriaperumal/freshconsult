require 'rubygems'
require 'jira4r'
require 'json'

class Integrations::JiraIssue

	def initialize(username, password, installed_app, params)
			@jira = Jira4R::JiraTool.new(2, params['domain'])
			@jira.login(username, password)
            @installed_app = installed_app unless installed_app.blank?
	end

	def create(params)
		issue = Jira4R::V2::RemoteIssue.new
		issue.project = params['projectId']
		issue.type = params['issueTypeId']
		issue.summary = params['summary']
		issue.description = params['description']
		resData = @jira.createIssue(issue)
		params['remoteKey'] = resData.key unless resData.key.blank? 
		resData = update(params)
		return resData.to_json
	end

	def get_issue_types(params)
		jsonArray = Array.new
		issueTypes = @jira.getIssueTypes()
        issueTypes.each { |i_type|
          jsonArray.push 'typeId' => i_type.id, 'typeName' => i_type.name
        }
		resJson = {'types' => jsonArray}
		return resJson
	end

	def delete(params)
		@jira.deleteIssue(params['integrated_resource']['remote_integratable_id'])
	end

	def update(params)
        customId = customFieldChecker
        if(customId)
			customField = Jira4R::V2::RemoteFieldValue.new
            customField.id = customId
			customField.values = params['ticketData']
			resData = @jira.updateIssue(params['remoteKey'], [customField])	
			comment = false
		else
			issueId = params['remoteKey']
			commentResponse = addCommentToJira(issueId, params['ticketData'])
			comment = true
		end
		if(comment == true && commentResponse != nil)
			resData = nil
		end	
		return resData
	end

    def delete_custom_field
        @installed_app[:configs][:inputs]['customFieldId'] = nil
        @installed_app.save!
    end

    def jira_serverinfo
        @jira.getServerInfo().version
    end

    private
	def getCustomFieldId
		customData = @jira.getCustomFields()
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
