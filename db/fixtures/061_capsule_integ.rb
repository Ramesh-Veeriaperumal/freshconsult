capsule_app = Integrations::Application.seed(:name) do |s|
  s.name = 'capsule_crm'
  s.display_name = "integrations.capsule.label"
  s.description = "integrations.capsule.desc"
  s.options = { :keys_order => [:title,:domain,:api_key,:bcc_drop_box_mail], 
  :title => { :type => :text, :required => true, :label => "integrations.capsule.form.widget_title", :default_value => "Capsule CRM"},
  :domain => { :type => :text, :required => true, :label => "integrations.capsule.form.domain", :info => "integrations.capsule.form.domain_info", :rel => "ghostwriter", :autofill_text => ".capsulecrm.com", :validator_type => "domain_validator" }, 
  :api_key => { :type => :text, :required => true, :label => "integrations.capsule.form.api_key", :info => "integrations.capsule.form.api_key_info" }, 
  :bcc_drop_box_mail => { :type => :multiemail, :required => false, :label => "integrations.capsule.form.bcc_drop_box_mail", :info => "integrations.capsule.form.bcc_drop_box_mail_info" }}
end

Integrations::Widget.seed(:application_id, :name) do |s|
  s.name = "contact_widget"
  s.description = "widgets.contact_widget.description"
  s.script = '<div id="capsule_widget" domain="{{capsule_crm.domain}}" title="{{capsule_crm.title}}"><div id="content"></div></div><script type="text/javascript">CustomWidget.include_js("/javascripts/capsule_crm.js");capsuleBundle={ t:"{{capsule_crm.api_key}}", reqId:"{{requester.id}}", reqName:"{{requester.name | escape_html}}", reqOrg:"{{requester.company_name}}", reqPhone:"{{requester.phone}}", reqEmail:"{{requester.email}}"}; </script>'
  s.application_id = capsule_app.id
end
