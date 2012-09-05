class Integrations::JiraUtil
  include Integrations::Constants
  include RedisKeys

  def install_jira_biz_rules(installed_app)
    jira_app_biz_rules = VARule.find_all_by_rule_type_and_account_id(VAConfig::APP_BUSINESS_RULE, SYSTEM_ACCOUNT_ID, 
                                        :joins=>"INNER JOIN app_business_rules ON app_business_rules.va_rule_id=va_rules.id", 
                                        :conditions=>["app_business_rules.application_id=?", installed_app.application_id]) if jira_app_biz_rules.blank? # for create
    jira_app_biz_rules.each { |jira_app_biz_rule|
      Rails.logger.debug "Before jira_app_biz_rule #{jira_app_biz_rule.inspect}"
      installed_biz_rule = VARule.find_by_name_and_rule_type_and_account_id(jira_app_biz_rule.name, VAConfig::INSTALLED_APP_BUSINESS_RULE, installed_app.account.id, 
                                        :joins=>"INNER JOIN app_business_rules ON app_business_rules.va_rule_id=va_rules.id", :select=>"va_rules.*", # explicit select needed to avoid read_only because of joins
                                        :conditions=>["app_business_rules.application_id=?", installed_app.application_id]) # for update
      if installed_biz_rule.blank?
        jira_app_biz_rule = jira_app_biz_rule.clone()
        jira_app_biz_rule.rule_type = VAConfig::INSTALLED_APP_BUSINESS_RULE
        jira_app_biz_rule.account_id = installed_app.account_id
        jira_app_biz_rule.build_app_business_rule(:application => installed_app.application)
      else
        jira_app_biz_rule = installed_biz_rule
      end

      Rails.logger.debug "After jira_app_biz_rule #{jira_app_biz_rule.inspect}"
      notify_value = installed_app.send("configs_#{jira_app_biz_rule.name}")
      if (notify_value.blank? || notify_value == "none")
        jira_app_biz_rule.app_business_rule.destroy unless jira_app_biz_rule.new_record?  # delete it if the option choosen is none.
      else
        jira_app_biz_rule.action_data[0][:notify_value] = notify_value
        jira_app_biz_rule.save!
      end
    }
  end

  def uninstall_jira_biz_rules(installed_app)
    installed_jira_biz_rules = Integrations::AppBusinessRule.find_all_by_application_id(installed_app.application_id, 
                                        :joins=>"INNER JOIN va_rules ON app_business_rules.va_rule_id=va_rules.id",
                                        :conditions=>["va_rules.rule_type=? and va_rules.account_id=?", VAConfig::INSTALLED_APP_BUSINESS_RULE, installed_app.account.id])
    installed_jira_biz_rules.each{ |installed_jira_biz_rule| installed_jira_biz_rule.destroy }
  end

  def status_changed(data, config)
    Rails.logger.debug("Notification for status_changed #{data.inspect}  #{config.inspect}")
    perform_jira_action(data, config[:notify_value])
  end

  def comment_added(data, config)
    Rails.logger.debug("Notification for comment_added #{data.inspect}  #{config.inspect}")
    perform_jira_action(data, config[:notify_value])
  end

  private 
    def perform_jira_action(data, notify_value)
      Rails.logger.debug "perform_jira_action #{notify_value}"
      account = data.account
      installed_jira_app = account.installed_applications.with_name(APP_NAMES[:jira]).first
      data_id = data.instance_of?(Helpdesk::Note) ? data.notable_id :  data.id
      resource_needs_to_be_notified = Integrations::IntegratedResource.find_by_account_id_and_local_integratable_id_and_installed_application_id(data.account.id, data_id, installed_jira_app)
      unless resource_needs_to_be_notified.blank?
        resource_needs_to_be_notified = [resource_needs_to_be_notified] unless resource_needs_to_be_notified.instance_of?(Array)
        jira_obj = Integrations::JiraIssue.new(installed_jira_app.configs_username, installed_jira_app.configsdecrypt_password, installed_jira_app, installed_jira_app.configs_domain)
        obj_mapper = Integrations::ObjectMapper.new
        resource_needs_to_be_notified.each {|notify_resource|
          issue_id = notify_resource.remote_integratable_id
          mapped_data = obj_mapper.map_it(account.id, notify_value, data, :ours_to_theirs, [:map])
          Rails.logger.debug "mapped_data #{mapped_data}"
          invoke_action = notify_value.match("comment_in_jira") ? "add_comment" : "update_status"
          jira_obj.send(invoke_action, issue_id, mapped_data)
          jira_key = INTEGRATIONS_JIRA_NOTIFICATION % {:account_id=>account.id, :local_integratable_id=>notify_resource.local_integratable_id, :remote_integratable_id=>notify_resource.remote_integratable_id}
          set_key(jira_key, "true", 60) # The key will expire within 60secs.
        }
      end
    end
end

# {:value=>"comment_added", :notify_value=>"add_comment_in_jira", :name=>"Integrations::JiraUtil"}
# {:value=>"status_changed", :notify_value=>"add_status_as_comment_in_jira", :name=>"Integrations::JiraUtil"}
# {:value=>"status_changed", :notify_value=>"update_jira_status", :name=>"Integrations::JiraUtil"}
# INSERT INTO `delayed_jobs` (`handler`, `attempts`, `run_at`, `locked_at`, `last_error`, `created_at`, `updated_at`, `priority`, `failed_at`, `locked_by`) VALUES('--- !ruby/struct:Delayed::PerformableMethod \nobject: AR:Helpdesk::Ticket:63\nmethod: :biz_rules_check\nargs: \n- - :update_status\n\"@account\": AR:Account:1\n', 0, '2012-08-08 05:26:17', NULL, NULL, '2012-08-08 05:26:17', '2012-08-08 05:26:17', 0, NULL, NULL);
