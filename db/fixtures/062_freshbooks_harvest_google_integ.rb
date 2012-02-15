# Populate freshbooks
freshbooks_app = Integrations::Application.seed(:name) do |s|
  s.name = "freshbooks"
  s.display_name = "integrations.freshbooks.label"  
  s.description = "integrations.freshbooks.desc"
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
#google_contacts_app = Integrations::Application.seed(:name) do |s|
#  s.name = "google_contacts"  # Do not change the name.
#  s.display_name = "integrations.google_contacts.label" 
#  s.description = "integrations.google_contacts.desc"
#  s.options = { 
#                :keys_order => [:account_settings], 
#                :account_settings => {:type => :custom, 
#                    :partial => "/integrations/applications/google_accounts", 
#                    :required => false, :label => "integrations.google_contacts.form.account_settings", 
#                    :info => "integrations.google_contacts.form.account_settings_info" }
#               }
#end
