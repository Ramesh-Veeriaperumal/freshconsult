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
    param_data =  { :local_integratable_id => @ticket.id, 
        :local_integratable_type => "issue-tracking",
        :application_id => @installed_application.application_id,
        :body => {:fields => {:project => {:id => "10000"}, :issuetype => {:id => "1"},
                  :summary => "rspec ticket - testing",
                  :reporter => {:name => @installed_application.configs_username}, :description => @installed_application.configs_jira_note, 
                  :priority => {:id => "1"}}} }
    @custom_fields_id_value_map.each do |custom_field_hash|
      custom_field_hash.each do |custom_field_id_str, custom_field_value|
        param_data[:body][:fields][custom_field_id_str.to_sym] = custom_field_value
      end
    end
    param_data[:body] = param_data[:body].to_json
    param_data
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

  def get_array_custom_field_value(arr_custom_field_type, allowed_values)
    temp_array = []
    temp_array.push("Example Label") if arr_custom_field_type == "com.atlassian.jira.plugin.system.customfieldtypes:labels"
    temp_array.push({ "name" => "sathappan@freshdesk.com" }) if arr_custom_field_type == "com.atlassian.jira.plugin.system.customfieldtypes:multiuserpicker" 
    temp_array.push({ "name" => "users" }) if arr_custom_field_type == "com.atlassian.jira.plugin.system.customfieldtypes:multigrouppicker"
    temp_array.push({ "name" => "1.0" }) if arr_custom_field_type == "com.atlassian.jira.plugin.system.customfieldtypes:multiversion"
    if arr_custom_field_type == "com.atlassian.jira.plugin.system.customfieldtypes:multiselect"
      allowed_values.each do |allowed_value_hash|
        temp_array.push({ "value" => allowed_value_hash["value"] })
      end
    end
    temp_array
  end

  def get_custom_field_value(custom_field_type, schema_custom = nil, schema_allowed_values = nil)
    value = rand(10) if custom_field_type == "number"
    value = get_array_custom_field_value(schema_custom, schema_allowed_values) if custom_field_type == "array"
    value = "Some random string " if custom_field_type == "string"
    value
  end

  #returns an array of the form
  #[ "customfield_10008" => [ {"value" => "red" }, {"value" => "blue" }, {"value" => "green" }]
  # "customfield_10009" => [ {"name" => "jsmith" }, {"name" => "bjones" }, {"name" => "tdurden" }]
  # "customfield_10006" => ["examplelabel1", "examplelabel2"],
  # "customfield_10004" => "example text" ,
  # "customfield_10005" => 10 ]
  def get_custom_fields(project_id = "10000", type_id = "1") #should call this only once, costly API call and gets blocked on short successive calls.
    custom_fields_arr = []
    field_data = {
      :username => @installed_application[:configs][:inputs]['username'],
      :password => "legolas",
      :domain => @installed_application[:configs][:inputs]['domain'],
      :rest_url => "rest/api/latest/issue/createmeta?expand=projects.issuetypes.fields&projectIds="+project_id+"&issuetypeIds="+type_id,
      :method => "get",
      :content_type => "application/json"
    }
    request_proxy = HttpRequestProxy.new
    custom_data = request_proxy.fetch(field_data, nil)
    custom_data_json = ActiveSupport::JSON.decode(custom_data[:text])
    custom_data_json["projects"][0]["issuetypes"][0]["fields"].each do |field_key, field_value|
      if field_value["required"] == true && field_value["schema"]["customId"]
        custom_field_id = "customfield_"+"#{field_value['schema']['customId']}"
        custom_field_value = get_custom_field_value(field_value["schema"]["type"], field_value["schema"]["custom"], field_value["allowedValues"])
        custom_fields_arr.push({ custom_field_id => custom_field_value })
      end
    end
    custom_fields_arr
  end
end