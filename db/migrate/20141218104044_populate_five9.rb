class PopulateFive9< ActiveRecord::Migration
  shard :all
  @app_name = "five9"
  def self.up
  	five9 = Integrations::Application.create(
        :name => "five9",
        :display_name => "integrations.five9.label",
        :description => "integrations.five9.desc",
        :listing_order => 28,
        :options => {:direct_install => false,:keys_order => [:recording_path],
        :recording_path => { :type => :text, :required => true, :label => "integrations.five9.recording_path", 
        :info => "integrations.five9.recording_path_info"}},
        :application_type => "cti_integration",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    five9.save
  end

  def self.down
  	execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end
