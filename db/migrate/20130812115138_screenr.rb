class Screenr < ActiveRecord::Migration
  @app_name = "screenr"
  shard :none

  def self.up
    display_name = "integrations.screenr.label"
    description = "integrations.screenr.desc"
    listing_order = 22,
    application_type = @app_name
    options = {
        :keys_order => [:site_address, :recorder_id, :account_settings], 
        :site_address => { :type => :text, :required => true, :label => "integrations.screenr.form.site_address", :info => "integrations.screenr.form.site_address_info", :rel => "ghostwriter", :autofill_text => ".viewscreencasts.com"},
        :recorder_id => { :type => :text, :required => true, :label => "integrations.screenr.form.recorder_id", :info => "integrations.screenr.form.recorder_id_info" },
        :account_settings => { :type => :custom, :required => false, :label => "integrations.google_contacts.form.account_settings", :partial => "/integrations/applications/screenr_settings", :info => "integrations.google_contacts.form.account_settings_info" }
    }.to_yaml

    execute("INSERT INTO applications(name, display_name, description, options, listing_order, application_type) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}', '#{application_type}')")
    # res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    # res.data_seek(0)
    # app_id = res.fetch_row[0]
    Rails.logger.debug "INSERTED screenr app"
  end

  def self.down
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end