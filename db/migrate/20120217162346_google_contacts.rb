class GoogleContacts < ActiveRecord::Migration
  def self.up
    create_table :google_accounts do |t|
      t.string :name
      t.string :email
      t.string :token
      t.string :secret
      t.column :account_id, "bigint unsigned"
      t.string :sync_group_id, :null => false, :default => "0"
      t.string :sync_group_name, :null => false, :default => "All"
      t.column :sync_tag_id, "bigint unsigned"
      t.integer :sync_type, :null => false, :default => 0  # 0 is for MERGE_LATEST
      t.datetime :last_sync_time, :null => false, :default => '1970-01-01 00:00:00'
      t.string :last_sync_status
      t.boolean :overwrite_existing_user, :null => false, :default => true
      t.timestamps
    end

    create_table :key_value_pairs do |t|
      t.string :key
      t.string :value
      t.string :obj_type
      t.column :account_id, "bigint unsigned"
    end

    add_column :users, :address, :string
    add_column :users, :google_id, :string
    add_column :users, :google_viewer_id, :string

    google_contacts = Integrations::Application.create(
        :name => "google_contacts",  # Do not change the name.
        :display_name => "integrations.google_contacts.label", 
        :description => "integrations.google_contacts.desc", 
        :options => { 
                      :keys_order => [:account_settings], 
#                      :sync_type => { :type => :dropdown, 
#                          :choices => ["integrations.google_contacts.overwrite_local", "integrations.google_contacts.overwrite_remote", "integrations.google_contacts.merge_local", "integrations.google_contacts.merge_remote"], 
#                          :required => true, :label => "integrations.google_contacts.form.sync_type",   
#                          :info => "integrations.google_contacts.form.sync_type_info" }, 
                      :account_settings => {:type => :custom, 
                          :partial => "/integrations/applications/google_accounts", 
                          :required => false, :label => "integrations.google_contacts.form.account_settings", 
                          :info => "integrations.google_contacts.form.account_settings_info" }})
    google_contacts.save
  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => "google_contacts"}).delete
    remove_column :users, :google_viewer_id
    remove_column :users, :google_id
    remove_column :users, :address
    drop_table :key_value_pairs
    drop_table :google_accounts
  end
end
