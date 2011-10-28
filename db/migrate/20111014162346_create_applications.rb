class CreateApplications < ActiveRecord::Migration
  def self.up
    create_table :applications do |t|
      t.string :name
      t.string :p_name
      t.string :description
      t.integer :widget_id
      t.text :options
    end

    create_table :widgets do |t|
      t.string :name
      t.string :description
      t.text :script
      t.integer :application_id
    end

    create_table :installed_applications do |t|
      t.integer :application_id
      t.integer :account_id
      t.string :configs
    end

    capsuleApp = Integrations::Application.create(:name=>"Capsule CRM Application", :p_name=>"capsule_crm", :description=>"Capsule crm contact widget will be displyed in ticket and contact view page.", :options=>{:title=>{:type=>:text, :required=>:true, :label=>"Widget Title", :default_value=>"Capsule CRM"}, :api_key=>{:type=>:text, :required=>:true, :label=>"Api Key"}, :domain=>{:type=>:text, :required=>:true, :label=>"Domain (Ex: example.capsulecrm.com"}})
    capsuleApp.widgets.build(:name=>"contact_widget", :description=>"Display a contact or option to add the contact into capsule.", :script=>'<div id="capsule_widget" domain="{{capsule_crm.domain}}" title="{{capsule_crm.title}}"><div id="content"></div></div><script type="text/javascript"> CustomWidget.include_js("/javascripts/capsule_crm.js");capsuleBundle={t:"{{capsule_crm.api_key}}",reqId:"{{requester.id}}", reqName:"{{requester.name}}",reqOrg:"{{requester.company_name}}", reqPhone:"{{requester.phone}}",reqEmail:"{{requester.email}}"};</script>')
    capsuleApp.save
  end

  def self.down
    drop_table :applications
    drop_table :widgets
    drop_table :installed_applications
  end
end
