class Integrations::JiraWebhook

  attr_accessor :updated_entity_type, :notification_cause, :updated_time, :params

  def initialize(params)
    self.parse_jira_webhook(params)
    self.params = params
  end

  def parse_jira_webhook(params)
    epoch_time = params["timestamp"]/1000
    self.updated_time = Time.at(epoch_time.to_i)
    # self.updated_fields = params["updatedFields"]

    parse_matches = /(issue)_(comment)?_?(.*)/.match(params["id"])
    unless(parse_matches.blank?)
      if(parse_matches[2].blank?) # Pure issue related change.
        self.updated_entity_type = parse_matches[1]
        self.notification_cause = parse_matches[3]
      else # Comment related change.
        self.updated_entity_type = parse_matches[2]
        self.notification_cause = parse_matches[3] == "ed"? "added" : parse_matches[3]
      end
    end
  end

  def update_local(installed_application)
    notify_value = nil
    if self.updated_entity_type == "comment" and (self.notification_cause == "added" || self.notification_cause == "edited")
      notify_value = installed_application.configs_jira_comment_sync
    elsif self.updated_entity_type == "issue" and self.notification_cause != "updated" # Any notification other than update notification will be propagated to Freshdesk.  Even if we encouter some non-status related notification the same status will be updated one more time in Freshdesk, which is ok.
      notify_value = installed_application.configs_jira_status_sync
    end
    Rails.logger.debug "update_local #{notification_cause} #{updated_entity_type} #{notify_value}, installed_application #{installed_application}"
    obj_mapper = Integrations::ObjectMapper.new
    obj_mapper.map_it(installed_application.account_id, notify_value, self.params) unless notify_value.blank?
  end
end

# Issue resolved with comment - {"id"=>"issue_resolved", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316846181, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10925, "body"=>"resolve issue", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue reopened with comment - {"id"=>"issue_reopened", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316805340, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10924, "body"=>"reopen issue", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Reopened", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue closed without comment - {"id"=>"issue_closed", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316772790, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "action"=>"notify", "issue"=>{"status"=>"Closed", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue type udated - {"id"=>"issue_updated", "updatedFields"=>[{"name"=>"issuetype", "oldValue"=>"Bug", "newValue"=>"Improvement"}], "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344317336290, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Issue priority updated - {"id"=>"issue_updated", "updatedFields"=>[{"name"=>"priority", "oldValue"=>"Major", "newValue"=>"Critical"}], "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344317375407, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Comment Add - {"id"=>"issue_commented", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316605213, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10923, "body"=>"Adding comment.", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
# Comment Edit - {"id"=>"issue_comment_edited", "user_id"=>"navaneeth@freshdesk.com", "timestamp"=>1344316686504, "controller"=>"integrations/jira_issue", "user"=>"navaneeth@freshdesk.com", "comment"=>{"id"=>10923, "body"=>"Editing comment.", "author"=>"navaneeth@freshdesk.com"}, "action"=>"notify", "issue"=>{"status"=>"Resolved", "key"=>"TST-2", "summary"=>"Mail signature sent in wrong format.", "reporterName"=>"navaneeth@freshdesk.com"}}
