class GoogleDrive < ActiveRecord::Migration
  shard :all

  @app_name = "google_drive"

  def migrate(direction)
    self.send(direction)
  end

  def self.up
    Integrations::Application.create(
          :name => @app_name,
          :display_name => "integrations.google_drive.label", 
          :description => "integrations.google_drive.desc", 
          :listing_order => 51,
          :application_type => "google_drive",
          :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
          :options => {
              :keys_order => [:client_id, :developer_key], 
              :client_id => { :type => :text, :required => true, :label => "integrations.google_drive.form.client_id" },
              :developer_key => { :type => :text, :required => true, :label => "integrations.google_drive.form.developer_key" },
          })
  end

  def self.down
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
  end
  
end
