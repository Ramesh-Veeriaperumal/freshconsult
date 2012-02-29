module Integrations::JiraSystem

  def jira_authenticity(params)
  	username = params[:configs][:username]
    password = params[:configs][:password]
    params[:domain] = params[:configs][:domain]
    jiraObj = Integrations::JiraIssue.new(username, password, nil, params)
    jiraObj.jira_serverinfo
  end

 end