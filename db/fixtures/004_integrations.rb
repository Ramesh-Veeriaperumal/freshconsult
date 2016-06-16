if Integrations::Application.count == 0
  # Populate Capsule CRM
  capsule_app = Integrations::Application.seed(:name) do |s|
    s.name = 'capsule_crm'
    s.display_name = "integrations.capsule.label"
    s.description = "integrations.capsule.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 1
    s.options = { :keys_order => [:title,:domain,:api_key,:bcc_drop_box_mail], 
    :title => { :type => :text, :required => true, :label => "integrations.capsule.form.widget_title", :default_value => "Capsule CRM"},
    :domain => { :type => :text, :required => true, :label => "integrations.capsule.form.domain", :info => "integrations.capsule.form.domain_info", :rel => "ghostwriter", :autofill_text => ".capsulecrm.com", :validator_type => "domain_validator" }, 
    :api_key => { :type => :text, :required => true, :label => "integrations.capsule.form.api_key", :info => "integrations.capsule.form.api_key_info" }, 
    :bcc_drop_box_mail => { :type => :multiemail, :required => false, :label => "integrations.capsule.form.bcc_drop_box_mail", :info => "integrations.capsule.form.bcc_drop_box_mail_info" }}
    s.application_type = "capsule_crm"
  end
  
  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "contact_widget"
    s.description = "widgets.contact_widget.description"
    s.script = '<div id="capsule_widget" domain="{{capsule_crm.domain}}" title="{{capsule_crm.title}}"><div class="content"></div></div><script type="text/javascript">CustomWidget.include_js("/javascripts/capsule_crm.js");capsuleBundle={ t:"{{capsule_crm.api_key}}", reqId:"{{requester.id}}", reqName:"{{requester.name | escape_html}}", reqOrg:"{{requester.company_name}}", reqPhone:"{{requester.phone}}", reqEmail:"{{requester.email}}"}; </script>'
    s.application_id = capsule_app.id
  end
  
  
  # Populate freshbooks
  freshbooks_app = Integrations::Application.seed(:name) do |s|
    s.name = "freshbooks"
    s.display_name = "integrations.freshbooks.label"  
    s.description = "integrations.freshbooks.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 2
    s.options = {
        :keys_order => [:title, :api_url, :api_key, :settings], 
        :title => { :type => :text, :required => true, :label => "integrations.freshbooks.form.widget_title", :default_value => "Freshbooks"},
        :api_url => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_url", :info => "integrations.freshbooks.form.api_url_info", :validator_type => "url_validator" }, 
        :api_key => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_key", :info => "integrations.freshbooks.form.api_key_info" },
        :settings => { :type => :custom, :required => false, :label => "integrations.google_contacts.form.account_settings", :partial => "/integrations/applications/invoice_timeactivity_settings" }
    }
    s.application_type = "freshbooks"
  end
  
  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "freshbooks_timeentry_widget"
    s.description = "freshbooks.widgets.timeentry_widget.description"
    s.script = %{
      <div id="freshbooks_widget" api_url="{{freshbooks.api_url}}" title="{{freshbooks.title}}">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/freshbooks.js");
        freshbooksBundle={ k:"{{freshbooks.api_key}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", freshbooksNote:"{{freshbooks.freshbooks_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
       </script>}
    s.application_id = freshbooks_app.id
  end
  
  
  # Populate harvest
  harvest_app = Integrations::Application.seed(:name) do |s|
    s.name = "harvest"
    s.display_name = "integrations.harvest.label"  
    s.description = "integrations.harvest.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 3
    s.options = {
        :keys_order => [:title, :domain, :harvest_note], 
        :title => { :type => :text, :required => true, :label => "integrations.harvest.form.widget_title", :default_value => "Harvest"},
        :domain => { :type => :text, :required => true, :label => "integrations.harvest.form.domain", :info => "integrations.harvest.form.domain_info", :rel=> "ghostwriter", :autofill_text => ".harvestapp.com", :validator_type => "domain_validator" }, 
        :harvest_note => { :type => :text, :required => false, :label => "integrations.harvest.form.harvest_note", 
                            :info => "integrations.harvest.form.harvest_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' },
        :install => {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}},
        :edit => {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}}
    }
    s.application_type = "harvest"
  end
  
  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "harvest_timeentry_widget"
    s.description = "harvest.widgets.timeentry_widget.description"
    s.script = %{
      <div id="harvest_widget" title="{{harvest.title}}">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/harvest.js");
        harvestBundle={domain:"{{harvest.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", harvestNote:"{{harvest.harvest_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
       </script>}
    s.application_id = harvest_app.id
  end
  
  
  # Populate Google contacts
  google_contacts_app = Integrations::Application.seed(:name) do |s|
    s.name = "google_contacts"  # Do not change the name.
    s.display_name = "integrations.google_contacts.label" 
    s.description = "integrations.google_contacts.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 4
    s.options = { 
                  :keys_order => [:account_settings], 
                  :account_settings => {:type => :custom, 
                      :partial => "/integrations/applications/google_accounts", 
                      :required => false, :label => "integrations.google_contacts.form.account_settings", 
                      :info => "integrations.google_contacts.form.account_settings_info" },
                  :oauth_url => "/auth/google_contacts?origin=id%3D{{account_id}}%26app_name%3Dgoogle_contacts%26portal_id%3D{{portal_id}}"
                 }
    s.application_type = "google_contacts"
  end

  # Populate JIRA
  jira_app = Integrations::Application.seed(:name) do |s|
    s.name = "jira"  # Do not change the name.
    s.display_name = "integrations.jira.label" 
    s.description = "integrations.jira.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 5
    s.options = {
                  :keys_order => [:title, :domain, :username, :password, :jira_note, :sync_settings], 
                  :title => { :type => :text, :required => true, :label => "integrations.jira.form.widget_title", :default_value => "Atlassian Jira"},
                  :domain => { :type => :text, :required => true, :label => "integrations.jira.form.domain", :info => "integrations.jira.form.domain_info", :validator_type => "url_validator" }, 
                  :jira_note => { :type => :text, :required => false, :label => "integrations.jira.form.jira_note", 
                                      :info => "integrations.jira.form.jira_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}} - {{ticket.description_html}}', :css_class => "hide" },
                  :username => { :type => :text, :required => true, :label => "integrations.jira.form.username" },
                  :password => { :type => :password, :label => "integrations.jira.form.password" },
                  :sync_settings => { :type => :custom, :required => false, :partial => "/integrations/applications/jira_sync_settings",
                                      :info => "integrations.google_contacts.form.account_settings_info", :label => "integrations.google_contacts.form.account_settings"},
                  :after_save => { :method => "install_jira_biz_rules", :clazz => "Integrations::JiraUtil" },
                  :after_destroy => { :method => "uninstall_jira_biz_rules", :clazz => "Integrations::JiraUtil"} 
                }
    s.application_type = "jira"            
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "jira_widget"
    s.description = "jira.widgets.jira_widget.description"
    s.script = %{
      <div id="jira_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/atlassian-jira.js");
        jiraBundle={domain:"{{jira.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", jiraNote:"{{jira.jira_note | escape_html}}", ticketId:"{{ticket.id}}", ticket_rawId:"{{ticket.raw_id}}", ticketSubject:"{{ticket.subject}}", ticketDesc:"{{ticket.description_text}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}", username:"{{jira.username}}", custom_field_id:"{{jira.customFieldId}}" } ;
       </script>}
    s.application_id = jira_app.id
  end

  status_change_biz_rule = VaRule.seed(:account_id, :name) do |s|
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.rule_type = VAConfig::APP_BUSINESS_RULE
    s.name = "fd_status_sync"
    s.match_type = "any"
    s.filter_data = [
        { :name => "any", :operator => "is", :value => "any", :action_performed=>{:entity=>"Helpdesk::Ticket", :action=>:update_status} } ]
    s.action_data = [
        { :name => "Integrations::JiraUtil", :value => "status_changed" } ]
    s.active = true
    s.description = 'This rule will update the JIRA status when linked ticket status is affected.'
  end

  status_change_jira_biz_rule = Integrations::AppBusinessRule.seed do |s|
    s.application = jira_app
    s.va_rule = status_change_biz_rule
  end

  comment_add_biz_rule = VaRule.seed(:account_id, :name) do |s|
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.rule_type = VAConfig::APP_BUSINESS_RULE
    s.name = "fd_comment_sync"
    s.match_type = "any"
    s.filter_data = [
        { :name => "any", :operator => "is", :value => "any", :action_performed=>{:entity=>"Helpdesk::Note", :action=>:create} } ]
    s.action_data = [
        { :name => "Integrations::JiraUtil", :value => "comment_added" } ]
    s.active = true
    s.description = 'This rule will add a comment in JIRA when a reply/note is added in the linked ticket.'
  end

  comment_add_jira_biz_rule = Integrations::AppBusinessRule.seed do |s|
    s.application = jira_app
    s.va_rule = comment_add_biz_rule
  end  

  #Google Analytics

  google_analytics_app = Integrations::Application.seed(:name) do |s|
    s.name = "google_analytics"  # Do not change the name.
    s.display_name = "integrations.google_analytics.label" 
    s.description = "integrations.google_analytics.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 6
    s.options = { 
                  :keys_order => [:google_analytics_settings], 
                  :google_analytics_settings => {:type => :custom, 
                      :partial => "/integrations/applications/google_analytics", 
                      :required => false, :label => "integrations.google_analytics.form.google_analytics_settings", 
                      :info => "integrations.google_analytics.form.google_analytics_settings_info" }
                }
    s.application_type = "google_analytics"            
  end

  #Sugar CRM

  sugarcrm_app = Integrations::Application.seed(:name) do |s|
    s.name = "sugarcrm"
    s.display_name = "integrations.sugarcrm.label"
    s.description = "integrations.sugarcrm.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 7
    s.options = {:direct_install => true,
                 :auth_url => "/integrations/sugarcrm/settings",
                 :edit_url => "/integrations/sugarcrm/edit",
                 :default_fields => { :account => ["Name:"], 
                                      :contact => ["Name:"],
                                      :lead => ["Name:"]  
                                    }
               }
    s.application_type = "sugarcrm"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "sugarcrm_widget"
    s.description = "sugarcrm.widgets.sugarcrm_widget.description"
    s.script = %{
      <div id="sugarcrm_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/sugarcrm.js");
        sugarcrmBundle={domain:"{{sugarcrm.domain}}", reqEmail:"{{requester.email}}", username:"{{sugarcrm.username}}", password:"{{sugarcrm.password}}"} ;
       </script>}
    s.application_id = sugarcrm_app.id
  end


  # Populate Workflow MAX
  wfmax_app = Integrations::Application.seed(:name) do |s|
    s.name = "workflow_max"  # Do not change the name.
    s.display_name = "integrations.workflow_max.label" 
    s.description = "integrations.workflow_max.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 8
    s.options = {
                  :keys_order => [:title, :api_key, :account_key, :workflow_max_note], 
                  :title => { :type => :text, :required => true, :label => "integrations.workflow_max.form.widget_title", :default_value => "Workflow MAX"},
                  :api_key => { :type => :text, :required => true, :label => "integrations.workflow_max.form.api_key", :info => "integrations.workflow_max.form.api_key_info" },
                  :account_key => { :type => :text, :required => true, :label => "integrations.workflow_max.form.account_key", :info => "integrations.workflow_max.form.account_key_info" },
                  :workflow_max_note => { :type => :text, :required => false, :label => "integrations.workflow_max.form.workflow_max_note", 
                                      :info => "integrations.workflow_max.form.workflow_max_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' },
                  :install => {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}},
                  :edit => {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}}
                }
    s.application_type = "workflow_max"            
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "workflow_max_timeentry_widget"
    s.description = "workflow_max.widgets.timeentry_widget.description"
    s.script = %{
      <div id="workflow_max_widget" title="{{workflow_max.title}}">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/workflow_max.js");
        workflowMaxBundle={ k:"{{workflow_max.api_key}}", a:"{{workflow_max.account_key}}", api_url:"https://api.workflowmax.com" , application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", workflowMaxNote:"{{workflow_max.workflow_max_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
      </script>}
    s.application_id = wfmax_app.id
  end

  #Populate Salesforce
  salesforce_app = Integrations::Application.seed(:name) do |s|
    s.name = "salesforce"
    s.display_name = "integrations.salesforce.label"
    s.description = "integrations.salesforce.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 9
    s.options = {:direct_install => true, :oauth_url => "/auth/salesforce?origin=id%3D{{account_id}}", 
      :edit_url => "/integrations/salesforce/edit"}
    s.application_type = "salesforce"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "salesforce_widget"
    s.description = "salesforce.widgets.salesforce_widget.description"
    s.script = %{
      <div id="salesforce_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
        <div class="salesforce-name error hide"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/salesforce.js");
        salesforceBundle={domain:"{{salesforce.instance_url}}", reqEmail:"{{requester.email}}", token:"{{salesforce.oauth_token}}", contactFields:"{{salesforce.contact_fields}}", leadFields:"{{salesforce.lead_fields}}", reqName:"{{requester.name}}"} ;
      </script>}
    s.application_id = salesforce_app.id
  end

  #LogMeIn

  logmein_app = Integrations::Application.seed(:name) do |s|
    s.name = "logmein"
    s.display_name = "integrations.logmein.label"
    s.description = "integrations.logmein.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 10
    s.options = {
      :keys_order => [:title, :company_id, :password], 
      :title => { :type => :text, :required => true, :label => "integrations.logmein.form.widget_title", :default_value => "LogMeIn Rescue"},
      :company_id => { :type => :text, :required => true, :label => "integrations.logmein.form.company_id", :info => "integrations.logmein.form.logmein_company_info" },
      :password => { :type => :password, :label => "integrations.logmein.form.password", :info => "integrations.logmein.form.logmein_sso_pwd_info" }
    }
    s.application_type = "logmein"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "logmein_widget"
    s.description = "logmein.widgets.logmein_widget.description"
    s.script = %{
      <div class="clearfix"><h3 class="title pull-left">{{logmein.title | encode_html}} </h3><div class="class="integrations-logmein_logo pull-right"></div></div>
      <div id="logmein_widget">
        <div class="content"></div>
        <div class="error hide"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/logmein.js");
        logmeinBundle={ticketId:"{{ticket.id}}", installed_app_id:"{{installed_app_id}}", agentId:"{{agent.id}}", accountId: "{{account_id}}", reqName:"{{requester.name}}", secret:"{{md5secret}}", pincode:"{{cache.pincode}}", pinTime:"{{cache.pintime}}", ssoId:"{{agent.email}}", companyId:"{{logmein.company_id}}", authcode:"{{logmein.authcode}}"} ;
      </script>}
    s.application_id = logmein_app.id
  end
  
  # Batchbook
  batchbook_app = Integrations::Application.seed(:name) do |s|
      s.name = "batchbook" 
      s.display_name = "integrations.batchbook.label"
      s.description = "integrations.batchbook.desc" 
      s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
      s.listing_order = 11
      s.options =  {
          :keys_order => [:domain, :api_key, :version], 
          :domain => {  :type => :text,
                  :required => true,
                  :label => "integrations.batchbook.form.domain",
                  :info => "integrations.batchbook.form.domain_info",
                  :rel => "ghostwriter",
                  :autofill_text => ".batchbook.com",
                  :validator_type => "domain_validator"
                }, 
          :api_key => { :type => :text, :required => true, :label => "integrations.batchbook.form.api_key" },
          :version => { :type => :dropdown,
                        :choices => [
                                        ["integrations.batchbook.form.version.auto_detect", "auto"],
                                        ["integrations.batchbook.form.version.new", "new"],
                                        ["integrations.batchbook.form.version.classic", "classic"]
                                    ],
                        :required => true,
                        :default_value => "auto",
                        :label => "integrations.batchbook.form.version.label"
                },
          :before_save => {
                                    :method => 'detect_batchbook_version',
                                    :clazz => 'Integrations::BatchbookVersionDetector'
                          }
      }
      s.application_type = "batchbook"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "batchbook_widget"
    s.description = "batchbook.widgets.batchbook_widget.description"
    s.script = %(      
      <div id="batchbook_widget"  class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        jQuery(document).ready(function(){
          batchbookBundle={ domain:"{{batchbook.domain}}", k:"{{batchbook.api_key}}", reqEmail: "{{requester.email}}", reqName: "{{requester.name}}", ver: "{{batchbook.version}}"};
          CustomWidget.include_js("/javascripts/integrations/batchbook.js");
        });
      </script>
      )
    s.options = {'display_in_pages' => ["contacts_show_page_side_bar"]}
    s.application_id = batchbook_app.id
  end

  # Highrise CRM
  highrise_app = Integrations::Application.seed(:name) do |s|
    s.name = 'highrise'
    s.display_name = "integrations.highrise.label"  
    s.description = "integrations.highrise.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 12
    s.options = {
        :keys_order => [:domain, :api_key], 
        :domain => {  :type => :text,
                :required => true,
                :label => "integrations.highrise.form.domain",
                :info => "integrations.highrise.form.domain_info",
                #:validator_type => "url_validator",
                :rel => "ghostwriter",
                :autofill_text => ".highrisehq.com",
                :validator_type => "domain_validator"
              }, 
        :api_key => { :type => :text, :required => true, :label => "integrations.highrise.form.api_key" },
    }
    s.application_type = 'highrise'
  end

  #MailChimp

  mailchimp_app = Integrations::Application.seed(:name) do |s|
    s.name = "mailchimp"
    s.display_name = "integrations.mailchimp.label"
    s.description = "integrations.mailchimp.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 13
    s.options = {:direct_install => true, :oauth_url => "/auth/mailchimp?origin=id%3D{{account_id}}"}
    s.application_type = "mailchimp"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "mailchimp_widget"
    s.description = "mailchimp.widgets.mailchimp_widget.description"
    s.script = %{
      <div id="mailchimp_widget">
        <div class="error modal_error hide"></div>
        <div class="content"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/mailchimp.js");
        mailchimpBundle={api_endpoint:"{{mailchimp.api_endpoint}}", reqEmail:"{{requester.email}}", reqName:"{{requester.name}}",  token:"{{mailchimp.oauth_token}}", export: "{{export}}"  } ;
       </script>}
    s.application_id = mailchimp_app.id
    s.options =  {"display_in_pages" => ["contacts_show_page_side_bar"], "clazz" => "hide"}
  end

  #Campaign Monitor

  campaignmonitor_app = Integrations::Application.seed(:name) do |s|
    s.name = "campaignmonitor"
    s.display_name = "integrations.campaignmonitor.label"
    s.description = "integrations.campaignmonitor.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 14
    s.options = {
        :keys_order => [:api_key, :client_id], 
        :api_key => { :type => :text, :required => true, :label => "integrations.campaignmonitor.form.api_key", :info => "integrations.campaignmonitor.form.api_key_info" },
        :client_id => { :type => :text, :required => true, :label => "integrations.campaignmonitor.form.client_id", :info => "integrations.campaignmonitor.form.client_id_info" }
    }
    s.application_type = "campaignmonitor"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "campaignmonitor_widget"
    s.description = "campaignmonitor.widgets.campaignmonitor_widget.description"
    s.script = %{
      <div id="campaignmonitor_widget">
        <div class="error modal_error hide"></div>
        <div class="content"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/campaignmonitor.js");
        cmBundle={reqEmail:"{{requester.email}}", reqName:"{{requester.name}}", api_key:"{{campaignmonitor.api_key}}", client_id:"{{campaignmonitor.client_id}}", export: "{{export}}" } ;
       </script>}
    s.application_id = campaignmonitor_app.id
    s.options =  {"display_in_pages" => ["contacts_show_page_side_bar"], "clazz" => "hide"}
  end

  #iContact

  icontact_app = Integrations::Application.seed(:name) do |s|
    s.name = "icontact"
    s.display_name = "integrations.icontact.label"
    s.description = "integrations.icontact.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 15
    s.options = {
        :keys_order => [:api_url, :username, :password], 
        :api_url => { :type => :text, :required => true, :label => "integrations.icontact.form.api_url", :info => "integrations.icontact.form.api_url_info", :validator_type => "url_validator" }, 
        :username => { :type => :text, :required => true, :label => "integrations.icontact.form.username" },
        :password => { :type => :password, :label => "integrations.icontact.form.api_password" }
    }
    s.application_type = "icontact"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "icontact_widget"
    s.description = "icontact.widgets.icontact_widget.description"
    s.script = %{
      <div id="icontact_widget">
        <div class="error modal_error hide"></div>
        <div class="content"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/icontact.js");
        icontactBundle={reqEmail:"{{requester.email}}", reqName:"{{requester.name}}",  app_id:"{{icontact.app_id}}", username:"{{icontact.username}}", api_url:"{{icontact.api_url}}", app_id:"{{icontact.app_id}}", export: "{{export}}"  } ;
       </script>}
    s.application_id = icontact_app.id
    s.options =  {"display_in_pages" => ["contacts_show_page_side_bar"], "clazz" => "hide"}
  end

  #ConstantContact

  constantcontact_app = Integrations::Application.seed(:name) do |s|
    s.name = "constantcontact"
    s.display_name = "integrations.constantcontact.label"
    s.description = "integrations.constantcontact.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 16
    s.options = {:direct_install => true, :oauth_url => "/auth/constantcontact?origin=id%3D{{account_id}}"}
    s.application_type = "constantcontact"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "constantcontact_widget"
    s.description = "constantcontact.widgets.constantcontact_widget.description"
    s.script = %{
      <div id="constantcontact_widget">
        <div class="error modal_error hide"></div>
        <div class="content"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/constantcontact.js");
        ccBundle={reqEmail:"{{requester.email}}", reqName:"{{requester.name}}",  token:"{{constantcontact.oauth_token}}", export: "{{export}}", uid: "{{constantcontact.uid}}"  } ;
       </script>}
    s.application_id = constantcontact_app.id
    s.options =  {"display_in_pages" => ["contacts_show_page_side_bar"], "clazz" => "hide"}
  end

  # Nimble CRM
  nimble_app =  Integrations::Application.seed(:name) do |s|
    s.name = 'nimble'
    s.display_name = "integrations.nimble.label"
    s.description = "integrations.nimble.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 17
    s.options = {:direct_install => true, :oauth_url => "/auth/nimble?origin=id%3D{{account_id}}"}
    s.application_type = 'nimble'
  end

  # Zoho CRM
  zoho_app =  Integrations::Application.seed(:name) do |s|
    s.name = 'zohocrm'
    s.display_name = "integrations.zohocrm.label"  
    s.description = "integrations.zohocrm.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 18
    s.options = {
        :keys_order => [:api_key], 
        :api_key => { :type => :text, :required => true, :label => "integrations.zohocrm.form.api_key", :info => "integrations.zohocrm.form.api_key_info"}
    }
    s.application_type = 'zohocrm'
  end

  # Google Calendar
  googlecalendar_app = Integrations::Application.seed(:name) do |s|
    s.name = "google_calendar"
    s.display_name = "integrations.google_calendar.label"  
    s.description = "integrations.google_calendar.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.options = {
      :direct_install => true,
      :oauth_url => "/auth/google_calendar?origin=id%3D{{account_id}}%26app_name%3Dgoogle_calendar%26portal_id%3D{{portal_id}}%26user_id%3D{{user_id}}",
      :user_specific_auth => true,
      :auth_config => {
        :clazz => 'Integrations::GoogleCalendarEmailFinder',
        :method => 'find_and_store_user_registered_email'
      }
    }
    s.listing_order = 19
    s.application_type = "google_calendar"
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = 'google_calendar_widget'
    s.description = 'google_calendar.widgets.google_calendar.description'
    s.script = %(
      <link href="/stylesheets/pattern/pattern.css" media="screen" rel="stylesheet" type="text/css">
      <script src="/javascripts/pattern/bootstrap-typeahead.js" type="text/javascript"></script>

      <div id="google_calendar_widget"">
        <div class="content">
          <div class="title">
            <span>
              Google Calendar
            </span>

            <a href="#" class="pull-right" id="add_event_link">Add Event</a><br>
            <span id="gcal-email-container" class="hide">{{installed_app.user_registered_email}}</span>
            <br>
            <a href="{{installed_app.oauth_url}}" id="gcal-change-account-link" class="hide">Change</a>
          </div>
          <div class="gcal-content-body">
            <div id="gcal-older-events-link-container" class="hide"><span class="arrow-right" id="gcal-older-events-arrow"></span><a id="gcal-older-events-link" href="#older_events">Older Events</a></div> 
            <div id="google_calendar_events_container"></div>
          </div>
        </div>
      </div>

      <script type="text/javascript">
        var google_calendar_options={
          domain:"www.googleapis.com",
          application_id: {{application.id}},
          oauth_token:"{{installed_app.user_access_token}}",
          ticket_id: parseInt('{{ticket.id}}'),
          ticket_subject: "{{ticket.subject | encode_html | stip_newlines}}",
          events_list: [{{installed_app.events_list}}],
          oauth_url: "{{installed_app.oauth_url}}"
        };
        CustomWidget.include_js("/javascripts/integrations/google_calendar.js");
      </script>
    )
    s.options = {'display_in_pages' => ["helpdesk_tickets_show_page_side_bar"]}
    s.application_id = googlecalendar_app.id
  end

  # Dropbox
  dropbox_app = Integrations::Application.seed(:name) do |s|
    s.name = 'dropbox'
    s.display_name = "integrations.dropbox.label"
    s.description = "integrations.dropbox.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 20
    s.options = {:app_key=>{:required=>:true,:type=>:text,:label=>"integrations.dropbox.form.app_key",:info=>"integrations.dropbox.form.app_key_info"},:keys_order=>[:app_key]}
    s.application_type = 'dropbox'
  end

  surveymonkey_app = Integrations::Application.seed(:name) do |s|
    s.name = "surveymonkey"
    s.display_name = "integrations.surveymonkey.label"
    s.description = "integrations.surveymonkey.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 21
    s.application_type = 'surveymonkey'
    s.options = {
        :keys_order => [:settings], 
        :direct_install => true,
        :settings => { 
          :partial => 'integrations/surveymonkey/edit',
          :type => :custom,
          :required => false,
          :label => 'integrations.surveymonkey.form.survey_settings',
          :info => 'integrations.surveymonkey.form.survey_settings_info'
        },
        :configurable => true,
        :oauth_url => "/auth/surveymonkey?origin=id%3D{{account_id}}",
        :before_save => {
          :clazz => 'Integrations::SurveyMonkey',
          :method => 'sanitize_survey_text'
        },
        :after_save => {
          :clazz => 'Integrations::SurveyMonkey',
          :method => 'delete_cached_status'
        },
        :after_destroy => {
          :clazz => 'Integrations::SurveyMonkey',
          :method => 'delete_cached_status'
        }
    }

  end

  #populate pivotal tracker
  pivotal_tracker = Integrations::Application.seed(:name) do |s|
    s.name = "pivotal_tracker"
    s.display_name = "integrations.pivotal_tracker.label"  
    s.description = "integrations.pivotal_tracker.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 23
    s.options = { :keys_order => [:api_key, :pivotal_update],
                  :api_key => { :type => :text, :required => true, :label => "integrations.pivotal_tracker.api_key", :info => "integrations.pivotal_tracker.api_key_info"},
                  :pivotal_update => { :type => :checkbox, :label => "integrations.pivotal_tracker.pivotal_updates"}
                }
    s.application_type = "pivotal_tracker"
  end

  #populate shopify
  shopify_app = Integrations::Application.seed(:name) do |s|
    s.name = "shopify"
    s.display_name = "integrations.shopify.label"  
    s.description = "integrations.shopify.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 24
    s.options = {:direct_install => false, :keys_order => [:shop_name],
                 :shop_name => { :type => :text, :required => true, :label => "integrations.shopify.form.shop_name", :info => "integrations.shopify.form.shop_name_info", :rel => "ghostwriter", :autofill_text => ".myshopify.com"},
                 :no_settings => true,
                 :after_commit_on_create => { :clazz => "Integrations::ShopifyUtil", :method => "update_remote_integrations_mapping" },
                 :after_commit_on_destroy => { :clazz => "Integrations::ShopifyUtil", :method => "remove_remote_integrations_mapping" },
                 :install_action => { :url => { :controller => 'integrations/marketplace/shopify', :action => 'install' }, :html => {:method => 'put'} }
                }
    s.application_type = "shopify"
  end

  #populate seoshop
  seoshop_app = Integrations::Application.seed(:name) do |s|
    s.name = "seoshop"
    s.display_name = "integrations.seoshop.label"
    s.description = "integrations.seoshop.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 25
    s.options = {
   :keys_order => [:api_key, :api_secret, :language], 
   :api_key => {  :type => :text,
    :required => true,
    :label => "integrations.seoshop.form.api_key",
    :info => "integrations.seoshop.form.api_key_info"
    }, 
    :api_secret => { :type => :text, 
      :required  => true, 
      :label => "integrations.seoshop.form.api_secret",
      :info => "integrations.seoshop.form.api_secret_info"
      },
      :language => { :type => :dropdown,
        :choices => [
          ["integrations.seoshop.form.bg", "bg"],
          ["integrations.seoshop.form.da", "da"],
          ["integrations.seoshop.form.de", "de"],
          ["integrations.seoshop.form.en", "en"],
          ["integrations.seoshop.form.nl", "nl"],
          ["integrations.seoshop.form.fr", "fr"],
          ["integrations.seoshop.form.el", "el"],
          ["integrations.seoshop.form.it", "it"],
          ["integrations.seoshop.form.fr", "fr"],
          ["integrations.seoshop.form.nor", "\'no\'"],
          ["integrations.seoshop.form.pt", "pt"],
          ["integrations.seoshop.form.pl", "pl"],
          ["integrations.seoshop.form.ru", "ru"],
          ["integrations.seoshop.form.es", "es"],
          ["integrations.seoshop.form.sv", "sv"],
          ["integrations.seoshop.form.tr", "tr"]
          ],
          :required => true,
          :default_value => "en",
          :label => "integrations.seoshop.form.language"
        }
      }
    s.application_type = "seoshop"

  end

  box_app = Integrations::Application.seed(:name) do |s|
    s.name = "box"
    s.display_name = "integrations.box.label"
    s.description = "integrations.box.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 26
    s.options = {:direct_install => true, :oauth_url => "/auth/box?origin=id%3D{{account_id}}%26portal_id%3D{{portal_id}}%26user_id%3D{{user_id}}", :user_specific_auth => true}
    s.application_type = "box" 
  end 

  czentrix_app = Integrations::Application.seed(:name) do |s|
    s.name = "czentrix"
    s.display_name = "integrations.czentrix.label"
    s.description = "integrations.czentrix.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 27
    s.options = {:direct_install => false,:keys_order => [:host_ip,:convert_to_ticket,:add_note_as_private],
        :host_ip => { :type => :text, :required => true, :label => "integrations.czentrix.host_name", 
        :info => "integrations.czentrix.host_name_info"},
        :convert_to_ticket => {:type => :checkbox, :label => "integrations.cti.convert_to_ticket", :default_value => '1'},
        :add_note_as_private => {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'},
        :dimensions => {:width => "200px",:height => "450px"},
        :after_commit => {
          :clazz => 'Integrations::Cti',
          :method => 'clear_memcache'
        }
    }
    s.application_type = "cti_integration" 
  end 

  drishti_app = Integrations::Application.seed(:name) do |s|
    s.name = "drishti"
    s.display_name = "integrations.drishti.label"
    s.description = "integrations.drishti.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 28
    s.options = {
      :direct_install => false,
      :keys_order => [:host_ip,:convert_to_ticket,:add_note_as_private],
      :host_ip => { 
        :type => :text,
        :required => true, 
        :label => "integrations.drishti.host_name", 
        :info => "integrations.drishti.host_name_info"
        },
      :convert_to_ticket => {
        :type => :checkbox, 
        :label => "integrations.cti.convert_to_ticket", 
        :default_value => '1'
        },
      :add_note_as_private => {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'},
      :dimensions => {:width => "200px",:height => "450px"},
      :after_commit => {
        :clazz => 'Integrations::Cti',
        :method => 'clear_memcache'
      }
    }
    s.application_type = "cti_integration"
  end

  slack = Integrations::Application.seed(:name) do |s|
    s.name = "slack"
    s.display_name = "integrations.slack.label"  
    s.description = "integrations.slack.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 29
    s.options = { :keys_order => [:slack_settings],
                  :direct_install => true,
                  :slack_settings => { :type => :custom, :required => false, :label => "integrations.google_contacts.form.account_settings", :partial => "/integrations/applications/slack_setting" },
                  :configurable => true,
                  :oauth_url => "/auth/slack?origin=id%3D{{account_id}}",
                  :install => {:deprecated => {:notice => 'integrations.deprecated_message'}}
                }
    s.application_type = "slack"
  end
  
  quickbooks = Integrations::Application.seed(:name) do |s|
    s.name = "quickbooks"
    s.display_name = "integrations.quickbooks.label"
    s.description = "integrations.quickbooks.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 32
    s.options = {
      :direct_install => true,
      :configurable => true,
      :keys_order => [:settings],
      :settings => {
        :type => :custom,
        :required => false,
        :partial => "/integrations/applications/invoice_timeactivity_settings",
        :label => "integrations.quickbooks.form.account_settings"
      },
      :after_destroy => {
        :clazz => "Integrations::QuickbooksUtil",
        :method => "remove_app_from_qbo"
      },
      :after_create => {
        :clazz => "Integrations::QuickbooksUtil",
        :method => "add_remote_integrations_mapping"
      }
    }
    s.application_type = "quickbooks"
  end

  five9 = Integrations::Application.seed(:name) do |s|
    s.name = "five9"
    s.display_name = "integrations.five9.label"
    s.description = "integrations.five9.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 30
    s.options = { 
      :direct_install => false,
      :keys_order => [:convert_to_ticket, :add_note_as_private],
      :add_note_as_private => {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'},
      :convert_to_ticket => {:type => :checkbox, :label => "integrations.cti.convert_to_ticket", :default_value => '1'},
      :dimensions => {:width => "200px",:height => "450px"},
      :after_commit => {
        :clazz => 'Integrations::Cti',
        :method => 'clear_memcache'
      }
    }
    s.application_type = "cti_integration"
  end

  dynamics_crm = Integrations::Application.seed(:name) do |s|
    s.name = "dynamicscrm"
    s.display_name = "integrations.dynamicscrm.label"
    s.description = "integrations.dynamicscrm.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 31
    s.options = {  :direct_install => true,
                   :auth_url => "/integrations/dynamicscrm/settings",
                   :edit_url => "/integrations/dynamicscrm/edit",
                   :default_fields => {:contact => ["Telephone"], :account => ["Telephone"], :lead => ["Telephone"]}
                }
    s.application_type = "dynamicscrm"
  end

  xero =  Integrations::Application.seed(:name) do |s|
    s.name = "xero"
    s.display_name = "integrations.xero.label"
    s.description = "integrations.xero.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 33
    s.options = {:direct_install => true, :auth_url=> "/integrations/xero/authorize", 
      :edit_url => "/integrations/xero/edit"}
    s.application_type = "xero"
  end

  knowlarity = Integrations::Application.seed(:name) do |s|
    s.name = "knowlarity"
    s.display_name = "integrations.knowlarity.label"
    s.description = "integrations.knowlarity.desc"
    s.listing_order = 34
    s.options = {
      :direct_install => false,
      :keys_order => [:knowlarity_number,:api_key,:convert_to_ticket,:add_note_as_private],
      :knowlarity_number => { :type => :text, :required => true, :label => "integrations.knowlarity.number",:info => "integrations.knowlarity.number_info"},
      :api_key => { :type => :text, :required => true, :label => "integrations.knowlarity.api_key",:info => "integrations.knowlarity.apikey_info"},
      :convert_to_ticket => {:type => :checkbox, :label => "integrations.cti.convert_to_ticket", :default_value => '1'},
      :add_note_as_private => {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'},
      :dimensions => {:width => "200px",:height => "450px"},
      :after_commit => {
        :clazz => 'Integrations::Cti',
        :method => 'clear_memcache'
      }
    }
    s.application_type = "cti_integration"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
  end
  
  onedrive = Integrations::Application.seed(:name) do |s|
    s.name = "onedrive"
    s.display_name = "integrations.onedrive.label"
    s.description = "integrations.onedrive.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 35
    s.options = { :direct_install => true, :user_specific_auth => true }   
    s.application_type = "onedrive" 
  end 

  github_app =  Integrations::Application.seed(:name) do |s|
    s.name = "github"
    s.display_name = "integrations.github.label"
    s.description = "integrations.github.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 36
    s.options = {
      :direct_install => true,
      :oauth_url => "/auth/github?origin=id%3D{{account_id}}",
      :edit_url => "/integrations/github/edit",
      :after_commit_on_destroy => {
        :method => "uninstall",
        :clazz => "IntegrationServices::Services::GithubService",
      },
    }
    s.application_type = "github"
  end

  ilos =  Integrations::Application.seed(:name) do |s|
    s.name = "ilos"
    s.display_name = "integrations.ilos.label"
    s.description = "integrations.ilos.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 37
    s.options = {
        :keys_order => [:api_key, :account_settings], 
        :api_key => { :type => :text, :required => true, :label => "integrations.ilos.form.api_key" },
        :account_settings => { 
          :type => :custom, :required => false, :label => "integrations.google_contacts.form.account_settings", 
          :partial => "/integrations/applications/ilosvideos_settings", 
          :info => "integrations.google_contacts.form.account_settings_info" 
        }
    }
    s.application_type = "ilos"
  end

  magento =  Integrations::Application.seed(:name) do |s|
    s.name = "magento"
    s.display_name = "integrations.magento.label"
    s.description = "integrations.magento.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 38
    s.options = {:direct_install => true,
                 :auth_url => "/integrations/magento/new",
                 :edit_url => "/integrations/magento/edit"
                }
    s.application_type = "magento"
  end

  slack_v2 =  Integrations::Application.seed(:name) do |s|
    s.name = "slack_v2"
    s.display_name = "integrations.slack_v2.label"
    s.description = "integrations.slack_v2.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 39
    s.options = {:direct_install => true,
                 :auth_url => "/integrations/slack_v2/oauth",
                 :edit_url => "/integrations/slack_v2/edit"
                }
    s.application_type = "slack_v2"
  end

  infusionsoft = Integrations::Application.seed(:name) do |s|
    s.name = "infusionsoft"
    s.display_name = "integrations.infusionsoft.label"
    s.description = "integrations.infusionsoft.desc"
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 40
    s.options = {:direct_install => true, 
                 :edit_url => "infusionsoft/edit",
                 :oauth_url => "/auth/infusionsoft?origin=id%3D{{account_id}}", 
                 :default_fields => {:contact => ["First Name"], :account => ["Company"]}
                 }
    s.application_type = "infusionsoft"
  end

  #Populate Salesforce CRM Sync app
  salesforce_crm_sync_app = Integrations::Application.seed(:name) do |s|
    s.name = "salesforce_crm_sync"
    s.display_name = "integrations.salesforce_crm_sync.label"
    s.description = "integrations.salesforce_crm_sync.desc" 
    s.account_id = Integrations::Constants::SYSTEM_ACCOUNT_ID
    s.listing_order = 42
    s.options = {:direct_install => true, 
                 :oauth_url => "/auth/salesforce_crm_sync?origin=id%3D{{account_id}}", 
                 :edit_url => "/integrations/sync/crm/edit?state=sfdc&method=put",
                 :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }}
    s.application_type = "salesforce_crm_sync"
  end

end
