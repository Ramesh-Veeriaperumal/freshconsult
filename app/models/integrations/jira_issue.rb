require 'rubygems'
require 'jira4r'
require 'json'

class Integrations::JiraIssue

	def initialize(username, password, params)
			$jira = Jira4R::JiraTool.new(2, params['domain'])
			$jira.login(username, password)
	end

	def create(params)
		issue = Jira4R::V2::RemoteIssue.new
		issue.project = params['projectId']
		issue.type = params['issueTypeId']
		issue.summary = params['summary']
		issue.description = params['description']
		customId = getCustomFieldId()
		if customId
			freshdeskField = Jira4R::V2::RemoteCustomFieldValue.new
			freshdeskField.customfieldId = customId
			freshdeskField.values = params['ticketData']
			issue.customFieldValues = [freshdeskField]
		end
		resData = $jira.createIssue(issue)
		if customId.blank?
			unless resData.blank?
				jsonData = JSON.parse(resData.to_json)
				issueId = jsonData['key']
				commentResponse = addCommentToJira(issueId, params['ticketData'])
			end
			unless commentResponse.blank?
				resData = nil
			end
		end
		return resData.to_json
	end

	def show(params)
		jsonArray = Array.new
		issueTypes = $jira.getIssueTypes()
		i =0
		while i<issueTypes.length
		  issueHash = { 'typeId' => issueTypes[i].id, 'typeName' => issueTypes[i].name }
		  jsonArray.push(issueHash)
		  i = i+1
		end 
		resJson = {'types' => jsonArray}
		return resJson
	end

	def delete(params)
		resData = $jira.deleteIssue(params['integrated_resource']['remote_integratable_id'])
		return resData
	end

	def update(params)
		if(params['isCustomFieldDef'] == "true")
			customField = Jira4R::V2::RemoteFieldValue.new
			customField.id = params['customFieldId']
			puts params['ticketData']
			customField.values = params['ticketData']
			resData = $jira.updateIssue(params['remoteKey'], customField)	
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


	def getCustomFieldId()
		customData = $jira.getCustomFields()
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
		$jira.addComment(issueId, jiraComment)
	end
		
end
