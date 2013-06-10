class Integrations::JiraWebhook
  include Integrations::Jira::Api
  
  attr_accessor :updated_entity_type, :notification_cause, :updated_time, :params

  def initialize(params,http_request_proxy = nil)
    if(http_request_proxy)  
      @installed_app = params
      @http_request_proxy = http_request_proxy
    else
      self.params = params
      self.parse_jira_webhook(params)
    end
  end

  def register_webhooks
    current_url = @installed_app.account.url_protocol+"://"+@installed_app.account.full_domain +
                   "/integrations/jira_issue/notify?auth_key="+@installed_app[:configs][:inputs][:auth_key]
    req_data = {
          "name" => "Freshdesk webhook",
          "url"  =>  current_url,
          "events" =>  [
              # "jira:issue_created",
              "jira:issue_updated",
              # "jira:issue_deleted",
              # "jira:worklog_updated"
          ],
          "excludeIssueDetails" => false
        }
    webhook_data = construct_params_for_http(:register_webhooks)
    webhook_data[:body] = req_data.to_json
    make_rest_call(webhook_data, nil)
  end

  def delete_webhooks
    all_webhooks = available_webhooks
    all_webhooks.each do |webhook|
      if webhook["url"].include?("integrations/jira_issue/notify")
        webhook_delete = construct_params_for_http(:delete_webhooks,webhook["self"].split('/')[-1])
        make_rest_call(webhook_delete, nil)
      end
    end
  end

  def available_webhooks
    webhook_data = construct_params_for_http(:available_webhooks)
    res_data = make_rest_call(webhook_data, nil)
    unless(res_data[:exception])
      res_data[:json_data]
    else
      []
    end
  end

  def parse_jira_webhook(params)
    epoch_time = params["timestamp"]/1000
    self.updated_time = Time.at(epoch_time.to_i)
    # self.updated_fields = params["updatedFields"]

    parse_matches = /(jira):(issue)?_?(.*)/.match(params["webhookEvent"])
    unless(parse_matches.blank?)
      if(parse_matches[3] == "updated") # Pure issue related change.
        if(params["changelog"] && params["changelog"]["items"].collect{ |m| m["field"]}.include?("status"))
            self.params["updated_entity_type"] = self.updated_entity_type = "issue"
            self.params["notification_cause"] = self.notification_cause = "added when status is changed"
        elsif(params["comment"])
            self.params["updated_entity_type"] = self.updated_entity_type = "comment"
            self.params["notification_cause"] = self.notification_cause = (params["comment"]["created"]==params["comment"]["updated"]) ? "added" : "edited"
        end
      end
    end
  end

  def update_local(installed_application)
    notify_values = []
    if self.updated_entity_type == "comment" and (self.notification_cause == "added" || self.notification_cause == "edited")
      self.params["installed_application_id"] = installed_application.id
      notify_values.push installed_application.configs_jira_comment_sync
      notify_values.push "add_helpdesk_external_note_in_fd"
      if self.params["comment"]["author"]
        email = self.params["comment"]["author"]["emailAddress"]
        name =  self.params["comment"]["author"]["displayName"]
      end
    elsif self.updated_entity_type == "issue" and self.notification_cause != "updated" # Any notification other than update notification will be propagated to Freshdesk.  Even if we encouter any non-status related notification the same status will be updated one more time in Freshdesk, which is ok.
      notify_values.push installed_application.configs_jira_status_sync
      unless params["comment"].blank?
        notify_values.push installed_application.configs_jira_comment_sync 
        notify_values.push "add_helpdesk_external_note_in_fd"
      end 
      if self.params["user"]
        email = self.params["user"]["emailAddress"]
        name =  self.params["user"]["displayName"]
      end
    end
    create_a_contact(installed_application,email,name) if email && name
    Rails.logger.debug "update_local #{notification_cause}, #{updated_entity_type}, #{notify_values}, installed_application #{installed_application}"
    obj_mapper = Integrations::ObjectMapper.new
    
    params["admin"] = installed_application.account.account_managers.first
    notify_values.each do |notify_value| 
      self.params["comment"] = "" unless params["comment"]
      data = obj_mapper.map_it(installed_application.account_id, notify_value, self.params).id if notify_value 
      if params["comment"]
        self.params["note_id"] = data
      end
    end
  end

  def create_a_contact(installed_app,email,name)
    account = installed_app.account
    user = account.all_users.find_by_email(email) 
    unless user
      user = account.contacts.new
      if user.signup!({:user => {:name => name, :email => email, 
                       :active => true,:user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
       else
          puts "unable to save the contact:: #{user.errors.inspect}"
       end   
    end
     user
  end
end

# Issue resolved with comment - {"id"=>"issue_resolved", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316846181, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10925, "body"=>"resolve issue", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue reopened with comment - {"id"=>"issue_reopened", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316805340, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10924, "body"=>"reopen issue", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Reopened", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue closed without comment - {"id"=>"issue_closed", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316772790, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "action"=>"notify", "issue"=>{"status"=>"Closed", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue type udated - {"id"=>"issue_updated", "updatedFields"=>[{"name"=>"issuetype", "oldValue"=>"Bug", "newValue"=>"Improvement"}], "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344317336290, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue priority updated - {"id"=>"issue_updated", "updatedFields"=>[{"name"=>"priority", "oldValue"=>"Major", "newValue"=>"Critical"}], "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344317375407, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Comment Add - {"id"=>"issue_commented", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316605213, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10923, "body"=>"Adding comment.", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Comment Edit - {"id"=>"issue_comment_edited", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316686504, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10923, "body"=>"Editing comment.", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
#params["issue"]["fields"]["status"]["name"] status change
#["webhookEvent", "issue", "timestamp", "action", "user", "controller", "comment"]
#params["comment"]["body"]
# params["issue"]["key"]

