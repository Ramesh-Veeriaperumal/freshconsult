unless Account.current
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

  jira_app = Integrations::Application.seed(:name) do |s|
    s.name = "jira"  # Do not change the name.
    s.display_name = "integrations.jira.label" 
    s.description = "integrations.jira.desc"
    s.listing_order = 5
    s.options = {
                  keys_order => [:title, :domain, :username, :password, :jira_note], 
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

end
