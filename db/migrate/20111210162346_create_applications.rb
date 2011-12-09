class CreateApplications < ActiveRecord::Migration
  def self.up
    create_table :applications do |t|
      t.string :name  #TODO make it as unique key
      t.string :display_name
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
      t.timestamps
    end

    capsule_app = Integrations::Application.create(
        :name => "capsule_crm", 
        :display_name => "integrations.capsule.label",  
        :description => "integrations.capsule.desc",
        :options => {
            :keys_order => [:title,:domain,:api_key,:bcc_drop_box_mail], 
            :title => { :type => :text, :required => true, :label => "integrations.capsule.form.widget_title", :default_value => "Capsule CRM"},
            :domain => { :type => :text, :required => true, :label => "integrations.capsule.form.domain", :info => "integrations.capsule.form.domain_info" }, 
            :api_key => { :type => :text, :required => true, :label => "integrations.capsule.form.api_key" }, 
            :bcc_drop_box_mail => { :type => :email, :required => false, :label => "integrations.capsule.form.bcc_drop_box_mail", :info => "integrations.capsule.form.bcc_drop_box_mail_info" } 
         })

    capsule_app.widgets.build( :name => "contact_widget", 
                               :description => "widgets.contact_widget.description", 
                               :script => '<div id="capsule_widget" domain="{{capsule_crm.domain}}" title="{{capsule_crm.title}}"><div id="content"></div><div><script type="text/javascript">CustomWidget.include_js("/javascripts/capsule_crm.js");capsuleBundle={ t:"{{capsule_crm.api_key}}", reqId:"{{requester.id}}", reqName:"{{requester.name}}", reqOrg:"{{requester.company_name}}", reqPhone:"{{requester.phone}}", reqEmail:"{{requester.email}}"}; </script>' )
    capsule_app.save
  end

  def self.down
    drop_table :installed_applications
    drop_table :widgets
    drop_table :applications
  end
end
