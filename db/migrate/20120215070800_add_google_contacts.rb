class AddGoogleContacts < ActiveRecord::Migration
  @app_name = "google_contacts"

  def self.up
    execute('ALTER TABLE applications CHANGE COLUMN widget_id listing_order int(11) DEFAULT NULL')
    execute("ALTER TABLE google_accounts CHANGE COLUMN sync_group_name sync_group_name varchar(255) NOT NULL DEFAULT 'Freshdesk Contacts'")
    execute("ALTER TABLE google_accounts CHANGE COLUMN sync_group_id sync_group_id varchar(255) NULL")
    execute('UPDATE applications SET listing_order=id')
    google_contacts = Integrations::Application.create(
        :name => @app_name,
        :display_name => "integrations.google_contacts.label", 
        :description => "integrations.google_contacts.desc", 
        :listing_order => 4,
        :options => { 
                      :keys_order => [:account_settings], 
                      :account_settings => {:type => :custom, 
                          :partial => "/integrations/applications/google_accounts", 
                          :required => false, :label => "integrations.google_contacts.form.account_settings", 
                          :info => "integrations.google_contacts.form.account_settings_info" }})
    google_contacts.save
  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
    execute('UPDATE applications SET listing_order=NULL')
    execute('ALTER TABLE applications CHANGE COLUMN listing_order widget_id int(11) DEFAULT NULL')
  end
end
