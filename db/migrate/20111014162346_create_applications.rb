class CreateApplications < ActiveRecord::Migration
  def self.up
    create_table :applications do |t|
      t.string :name
      t.string :p_name #TODO make it as unique key
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
        :options => { :bcc_drop_box_mail => { :type => :email, :required => false, :label => "integrations.capsule.form.bcc_drop_box_mail", :info => "integrations.capsule.form.bcc_drop_box_mail_info" }, 
                      :domain => { :type => :text, :required => true, :label => "integrations.capsule.form.domain", :info => "integrations.capsule.form.domain_info" }, 
                      :api_key => { :type => :text, :required => true, :label => "integrations.capsule.form.api_key" }, 
                      :title => { :type => :text, :required => true, :label => "integrations.capsule.form.widget_title", :default_value => "Capsule CRM"}})
                              
    capsule_app.widgets.build( :name => "contact_widget", 
                               :description => "widgets.contact_widget.description", 
                               :script => "include_contact_widget")
    capsule_app.save
  end

  def self.down
    drop_table :installed_applications
    drop_table :widgets
    drop_table :applications
  end
end
