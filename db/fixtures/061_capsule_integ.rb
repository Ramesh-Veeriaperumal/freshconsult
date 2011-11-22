# capsule_app = Integrations::Application.create(
#             :name => "capsule_crm", 
#             :display_name => "capsule_crm_label",  
#             :description => "capsule_crm_desc",
#             :options => { :bcc_drop_box_mail => { :type => :text, :required => :false }, 
#                           :domain => { :type => :text, :required => :true }, 
#                           :api_key => { :type => :text, :required => :true }, 
#                           :title => { :type => :text, :required => :true, :default_value => "title_default_value"}})
#                           
# capsule_app.widgets.build( :name => "contact_widget", 
#                            :description => "contact_widget_description", 
#                            :script => "include_contact_widget")
# capsule_app.save

capsule_app = Integrations::Application.seed(:name) do |s|
  s.name = 'capsule_crm'
  s.display_name = "integrations.capsule.label"
  s.description = "integrations.capsule.desc"
  s.options = { :bcc_drop_box_mail => { :type => :text, :required => false, :label => "integrations.capsule.form.bcc_drop_box_mail", :info => "integrations.capsule.form.bcc_drop_box_mail_info" }, 
                :domain => { :type => :text, :required => true, :label => "integrations.capsule.form.domain", :info => "integrations.capsule.form.domain_info" }, 
                :api_key => { :type => :text, :required => true, :label => "integrations.capsule.form.api_key" }, 
                :title => { :type => :text, :required => true, :label => "integrations.capsule.form.widget_title", :default_value => "Capsule CRM"}}
end

Integrations::Widget.seed(:application_id, :name) do |s|
  s.name = "contact_widget"
  s.description = "widgets.contact_widget.description"
  s.script = "include_contact_widget"
  s.application_id = capsule_app.id
end
