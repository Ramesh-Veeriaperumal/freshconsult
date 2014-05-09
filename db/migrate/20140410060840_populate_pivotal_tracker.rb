class PopulatePivotalTracker < ActiveRecord::Migration
	shard :all
	@app_name = "pivotal_tracker"

  def self.up
  	display_name = "integrations.pivotal_tracker.label"  
    description = "integrations.pivotal_tracker.desc"
    listing_order = 23,
    options = {
        :keys_order => [:api_key, :pivotal_update], 
        :api_key => { :type => :text, :required => true, :label => "integrations.pivotal_tracker.api_key", :info => "integrations.pivotal_tracker.api_key_info"},
        :pivotal_update => { :type => :checkbox, :label => "integrations.pivotal_tracker.pivotal_updates"}
    }.to_yaml

    execute("INSERT INTO applications(name, display_name, description, options, listing_order, application_type) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}', '#{@app_name}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED PIVOTAL TRACKER APP ID #{app_id}"
  end

  def self.down
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end
