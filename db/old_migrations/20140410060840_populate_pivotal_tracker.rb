class PopulatePivotalTracker < ActiveRecord::Migration
	shard :all
	@app_name = "pivotal_tracker"

  def self.up
  	pivotal = Integrations::Application.create(
        :name => "pivotal_tracker",
        :display_name => "integrations.pivotal_tracker.label",
        :description => "integrations.pivotal_tracker.desc",
        :listing_order => 23,
        :options => {:keys_order => [:api_key, :pivotal_update],
        :api_key => { :type => :text, :required => true, :label => "integrations.pivotal_tracker.api_key", 
        :info => "integrations.pivotal_tracker.api_key_info"},
        :pivotal_update => { :type => :checkbox, :label => "integrations.pivotal_tracker.pivotal_updates"}},
        :application_type => "pivotal_tracker",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    pivotal.save
  end

  def self.down
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end
