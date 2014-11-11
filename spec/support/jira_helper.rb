module JiraHelper

	def create_installed_application(account)
    installed_application = FactoryGirl.build(:installed_application, 
      "application_id" => 5,
      "account_id" => account.id, 
      "configs" => { :inputs => { 
      "title" => "Atlassian Jira", 
      "domain" => "https://fresh-desk.atlassian.net",
      "username" => "sathappan@freshdesk.com",
      "jira_note" => "rspec Testing Ticket",
      "password" => "QwX4vYE25cZcKiqnLbnwHmD2cC9cWn40HT5EnjESaslWTA0lGpr2rlyAiSxq
                     HwvXDp8wlkW2NsVPAG00WhXsEc5YrWmWFHWP+tWlARHzspmE9dr1uCcYXNPw
                     dBEPADQcpr2m5ucl4HR7EBH5sVxfeax8czPo0xQSvuHO5qN25R9fwQnRn03+
                     dngsOjWfJk9Q/zmB9oRJp2EwXeOmeWcDjTaC2FmMumvq8j6ZF4Kms65dnEF5
                     4y2ruxLHFeg24P0rOmYFwbK+evqLCPW7WSkaQOGKK/5IkfwDaUgJvnJf3SWr
                     arjGLsJdSjtkDrIXO5nmQ/28Kr6juK2P8WK4AMryuw==",
		  "auth_key" => "f77d624058fc7b03480d1077ff691e2b",
      "customFieldId" => "customfield_11700" } }
      )
    installed_application.save(validate: false)
    installed_application
  end

  def create_params
    { :local_integratable_id => @ticket.id, 
      :local_integratable_type => "issue-tracking",
      :application_id => @installed_application.application_id,
      :body => {:fields => {:project => {:id => "10000"}, :issuetype => {:id => "1"},
                :summary => "rspec ticket - testing", 
                :customfield_13117 => "customer field 13117 fill up",
                :reporter => {:name => @installed_application.configs_username}, :description => @installed_application.configs_jira_note, 
                :priority => {:id => "1"}}}.to_json }
  end

  def unlink_params(integrated_resource)
    { :id => integrated_resource.id, 
      :remote_key => "#{integrated_resource.remote_integratable_id}", 
      :ticket_data => "##{@ticket.id} (http://#{@request.host}/helpdesk/tickets/#{@ticket.id}) - rspec testing" }
  end


  def update_params(integrated_resource)
    { :ticket_data => "##{@ticket.id} (http://#{@request.host}/helpdesk/tickets/#{@ticket.id}) - rspec testing",
      :local_integratable_id => @ticket.id, 
      :local_integratable_type => "issue-tracking", 
      :remote_key => "#{integrated_resource.remote_integratable_id}", 
      :application_id => @installed_application.application_id }
  end

  def notify_params(integrated_resource)
    { "webhookEvent" => "jira:issue_updated", "timestamp" => DateTime.now.strftime('%Q').to_i,
      "issue" => { "key" => integrated_resource.remote_integratable_id }, 
      "auth_key" => @installed_application.configs_auth_key,
      "user" => {"emailAddress" => @installed_application.configs_username, "displayName" => @agent.name },
      "changelog" => {"id" => "10300",
      "items" => [ 
      {"field" => "status", "fieldtype" => "jira", "from" => "1", "fromString" => "Open", 
      "to" => "6", "toString" => "Closed"}, 
      {"field" => "resolution", "fieldtype" => "jira", "from" => nil, "fromString" => nil, 
      "to" => "1", "toString" => "Fixed"}]}
    }
  end

end