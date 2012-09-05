class UpdateJira < ActiveRecord::Migration
  include Integrations::Constants
  @app_name = "jira"

  def self.up
    jira_app = Integrations::Application.first(:conditions=>["name='#{@app_name}'"])
    jira_app.options[:keys_order] = [:title, :domain, :username, :password, :jira_note, :sync_settings]
    jira_app.options[:jira_note][:css_class]="hide"
    jira_app.options[:after_save] = {:clazz => "Integrations::JiraUtil", :method => "install_jira_biz_rules"}
    jira_app.options[:after_destroy] = {:clazz => "Integrations::JiraUtil", :method => "uninstall_jira_biz_rules"}

    jira_app.options[:sync_settings] = {:type => :custom, 
                         :partial => "/integrations/applications/jira_sync_settings", 
                         :required => false, :label => "integrations.google_contacts.form.account_settings", 
                         :info => "integrations.google_contacts.form.account_settings_info" }
    jira_app.save!

    status_change_biz_rule = VARule.new
    status_change_biz_rule.account_id = SYSTEM_ACCOUNT_ID
    status_change_biz_rule.rule_type = VAConfig::APP_BUSINESS_RULE
    status_change_biz_rule.name = "fd_status_sync"
    status_change_biz_rule.match_type = "any"
    status_change_biz_rule.filter_data = [
        { :name => "any", :operator => "is", :value => "any", :action_performed=>{:entity=>"Helpdesk::Ticket", :action=>:update_status} } ]
    status_change_biz_rule.action_data = [
        { :name => "Integrations::JiraUtil", :value => "status_changed" } ]
    status_change_biz_rule.active = true
    status_change_biz_rule.description = 'This rule will update the JIRA status when linked ticket status is affected.'
    status_change_biz_rule.save!
    status_change_jira_biz_rule = Integrations::AppBusinessRule.new
    status_change_jira_biz_rule.application = jira_app
    status_change_jira_biz_rule.va_rule = status_change_biz_rule
    status_change_jira_biz_rule.save!

    comment_add_biz_rule = VARule.new
    comment_add_biz_rule.account_id = SYSTEM_ACCOUNT_ID
    comment_add_biz_rule.rule_type = VAConfig::APP_BUSINESS_RULE
    comment_add_biz_rule.name = "fd_comment_sync"
    comment_add_biz_rule.match_type = "any"
    comment_add_biz_rule.filter_data = [
        { :name => "any", :operator => "is", :value => "any", :action_performed=>{:entity=>"Helpdesk::Note", :action=>:create} } ]
    comment_add_biz_rule.action_data = [
        { :name => "Integrations::JiraUtil", :value => "comment_added" } ]
    comment_add_biz_rule.active = true
    comment_add_biz_rule.save!
    comment_add_biz_rule.description = 'This rule will add a comment in JIRA when a reply/note is added in the linked ticket.'
    comment_add_jira_biz_rule = Integrations::AppBusinessRule.new
    comment_add_jira_biz_rule.application = jira_app
    comment_add_jira_biz_rule.va_rule = comment_add_biz_rule
    comment_add_jira_biz_rule.save!
  end

  def self.down
    VARule.find_by_name_and_rule_type_and_account_id("fd_comment_sync", VAConfig::APP_BUSINESS_RULE, SYSTEM_ACCOUNT_ID).app_business_rule.destroy
    VARule.find_by_name_and_rule_type_and_account_id("fd_status_sync", VAConfig::APP_BUSINESS_RULE, SYSTEM_ACCOUNT_ID).app_business_rule.destroy
    jira_app = Integrations::Application.first(:conditions=>["name='#{@app_name}'"])
    jira_app.options[:jira_note].delete(:css_class)
    jira_app.options.delete(:sync_settings)
    jira_app.options.delete(:after_destroy)
    jira_app.options.delete(:after_save)
    jira_app.save!
  end
end

# { :type => :dropdown, :choices=> ["integrations.jira.form.do_nothing", "integrations.jira.form.add_note", "integrations.jira.form.send_reply", "integrations.jira.form.jira_status_sync_update_field", "integrations.jira.form.jira_status_sync_update_customer"], :inline=>true, :label => "integrations.jira.form.jira_status_sync" }
# jira_app.options[:jira_comment_sync] = { :type => :dropdown, :choices=> ["integrations.jira.form.do_nothing", "integrations.jira.form.add_note", "integrations.jira.form.send_reply"], :inline=>true, :label => "integrations.jira.form.jira_comment_sync" }
# jira_app.options[:fd_status_sync] = { :type => :dropdown, :choices=> ["integrations.jira.form.do_nothing", "integrations.jira.form.add_jira_comment", "integrations.jira.form.update_jira_status"], :inline=>true, :label => "integrations.jira.form.fd_status_sync" }
# jira_app.options[:fd_comment_sync] = { :type => :dropdown, :choices=> ["integrations.jira.form.do_nothing", "integrations.jira.form.add_jira_comment"], :inline=>true, :label => "integrations.jira.form.fd_comment_sync" }
