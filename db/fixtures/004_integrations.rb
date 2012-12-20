if Integrations::Application.count == 0
  # Populate Capsule CRM
  capsule_app = Integrations::Application.seed(:name) do |s|
    s.name = 'capsule_crm'
    s.display_name = "integrations.capsule.label"
    s.description = "integrations.capsule.desc"
    s.listing_order = 1
    s.options = { :keys_order => [:title,:domain,:api_key,:bcc_drop_box_mail], 
    :title => { :type => :text, :required => true, :label => "integrations.capsule.form.widget_title", :default_value => "Capsule CRM"},
    :domain => { :type => :text, :required => true, :label => "integrations.capsule.form.domain", :info => "integrations.capsule.form.domain_info", :rel => "ghostwriter", :autofill_text => ".capsulecrm.com", :validator_type => "domain_validator" }, 
    :api_key => { :type => :text, :required => true, :label => "integrations.capsule.form.api_key", :info => "integrations.capsule.form.api_key_info" }, 
    :bcc_drop_box_mail => { :type => :multiemail, :required => false, :label => "integrations.capsule.form.bcc_drop_box_mail", :info => "integrations.capsule.form.bcc_drop_box_mail_info" }}
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
    s.listing_order = 2
    s.options = {
        :keys_order => [:title, :api_url, :api_key, :freshbooks_note], 
        :title => { :type => :text, :required => true, :label => "integrations.freshbooks.form.widget_title", :default_value => "Freshbooks"},
        :api_url => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_url", :info => "integrations.freshbooks.form.api_url_info", :validator_type => "url_validator" }, 
        :api_key => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_key", :info => "integrations.freshbooks.form.api_key_info" },
        :freshbooks_note => { :type => :text, :required => false, :label => "integrations.freshbooks.form.freshbooks_note", 
                            :info => "integrations.freshbooks.form.freshbooks_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' }
    }
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
    s.listing_order = 3
    s.options = {
        :keys_order => [:title, :domain, :harvest_note], 
        :title => { :type => :text, :required => true, :label => "integrations.harvest.form.widget_title", :default_value => "Harvest"},
        :domain => { :type => :text, :required => true, :label => "integrations.harvest.form.domain", :info => "integrations.harvest.form.domain_info", :rel=> "ghostwriter", :autofill_text => ".harvestapp.com", :validator_type => "domain_validator" }, 
        :harvest_note => { :type => :text, :required => false, :label => "integrations.harvest.form.harvest_note", 
                            :info => "integrations.harvest.form.harvest_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' }}
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
    s.listing_order = 4
    s.options = { 
                  :keys_order => [:account_settings], 
                  :account_settings => {:type => :custom, 
                      :partial => "/integrations/applications/google_accounts", 
                      :required => false, :label => "integrations.google_contacts.form.account_settings", 
                      :info => "integrations.google_contacts.form.account_settings_info" }
                 }
  end

  # Populate JIRA
  jira_app = Integrations::Application.seed(:name) do |s|
    s.name = "jira"  # Do not change the name.
    s.display_name = "integrations.jira.label" 
    s.description = "integrations.jira.desc"
    s.listing_order = 5
    s.options = {
                  :keys_order => [:title, :domain, :username, :password, :jira_note], 
                  :title => { :type => :text, :required => true, :label => "integrations.jira.form.widget_title", :default_value => "Atlassian Jira"},
                  :domain => { :type => :text, :required => true, :label => "integrations.jira.form.domain", :info => "integrations.jira.form.domain_info", :validator_type => "url_validator" }, 
                  :jira_note => { :type => :text, :required => false, :label => "integrations.jira.form.jira_note", 
                                      :info => "integrations.jira.form.jira_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}} - {{ticket.description_text}}' },
                  :username => { :type => :text, :required => true, :label => "integrations.jira.form.username" },
                  :password => { :type => :password, :label => "integrations.jira.form.password" } 
                }
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


  #Google Analytics

  google_analytics_app = Integrations::Application.seed(:name) do |s|
    s.name = "google_analytics"  # Do not change the name.
    s.display_name = "integrations.google_analytics.label" 
    s.description = "integrations.google_analytics.desc"
    s.listing_order = 6
    s.options = { 
                  :keys_order => [:google_analytics_settings], 
                  :google_analytics_settings => {:type => :custom, 
                      :partial => "/integrations/applications/google_analytics", 
                      :required => false, :label => "integrations.google_analytics.form.google_analytics_settings", 
                      :info => "integrations.google_analytics.form.google_analytics_settings_info" }
                }
  end

  #Sugar CRM

  sugarcrm_app = Integrations::Application.seed(:name) do |s|
    s.name = "sugarcrm"
    s.display_name = "integrations.sugarcrm.label"
    s.description = "integrations.sugarcrm.desc" 
    s.listing_order = 7
    s.options = {
        :keys_order => [:domain, :username, :password], 
        :domain => { :type => :text, :required => true, :label => "integrations.sugarcrm.form.domain", :info => "integrations.sugarcrm.form.domain_info", :validator_type => "url_validator" }, 
        :username => { :type => :text, :required => true, :label => "integrations.sugarcrm.form.username" },
        :password => { :type => :password, :label => "integrations.sugarcrm.form.password", :encryption_type => "md5" }
    }
    
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
    s.listing_order = 8
    s.options = {
                  :keys_order => [:title, :api_key, :account_key, :workflow_max_note], 
                  :title => { :type => :text, :required => true, :label => "integrations.workflow_max.form.widget_title", :default_value => "Workflow MAX"},
                  :api_key => { :type => :text, :required => true, :label => "integrations.workflow_max.form.api_key", :info => "integrations.workflow_max.form.api_key_info" },
                  :account_key => { :type => :text, :required => true, :label => "integrations.workflow_max.form.account_key", :info => "integrations.workflow_max.form.account_key_info" },
                  :workflow_max_note => { :type => :text, :required => false, :label => "integrations.workflow_max.form.workflow_max_note", 
                                      :info => "integrations.workflow_max.form.workflow_max_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' }
                }
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
    s.listing_order = 9
    s.options = {:direct_install => true, :oauth_url => "/auth/salesforce?origin={{account_id}}"}
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
    s.listing_order = 10
    s.options = {
      :keys_order => [:title, :company_id, :password], 
      :title => { :type => :text, :required => true, :label => "integrations.logmein.form.widget_title", :default_value => "LogMeIn Rescue"},
      :company_id => { :type => :text, :required => true, :label => "integrations.logmein.form.company_id", :info => "integrations.logmein.form.logmein_company_info" },
      :password => { :type => :password, :label => "integrations.logmein.form.password", :info => "integrations.logmein.form.logmein_sso_pwd_info" }
    }
  end

  Integrations::Widget.seed(:application_id, :name) do |s|
    s.name = "logmein_widget"
    s.description = "logmein.widgets.logmein_widget.description"
    s.script = %{
      <div class="logmein-logo"><h3 class="title">{{logmein.title}} </h3></div>
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
                }
      }
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

  #MailChimp

  mailchimp_app = Integrations::Application.seed(:name) do |s|
    s.name = "mailchimp"
    s.display_name = "integrations.mailchimp.label"
    s.description = "integrations.mailchimp.desc" 
    s.listing_order = 13
    s.options = {:direct_install => true, :oauth_url => "/auth/mailchimp?origin={{account_id}}"}
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
    s.listing_order = 14
    s.options = {
        :keys_order => [:api_key, :client_id], 
        :api_key => { :type => :text, :required => true, :label => "integrations.campaignmonitor.form.api_key", :info => "integrations.campaignmonitor.form.api_key_info" },
        :client_id => { :type => :text, :required => true, :label => "integrations.campaignmonitor.form.client_id", :info => "integrations.campaignmonitor.form.client_id_info" }
    }
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
    s.listing_order = 15
    s.options = {
        :keys_order => [:api_url, :username, :password], 
        :api_url => { :type => :text, :required => true, :label => "integrations.icontact.form.api_url", :info => "integrations.icontact.form.api_url_info", :validator_type => "url_validator" }, 
        :username => { :type => :text, :required => true, :label => "integrations.icontact.form.username" },
        :password => { :type => :password, :label => "integrations.icontact.form.api_password" }
    }
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
    s.listing_order = 16
    s.options = {:direct_install => true, :oauth_url => "/auth/constantcontact?origin={{account_id}}"}
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

end
