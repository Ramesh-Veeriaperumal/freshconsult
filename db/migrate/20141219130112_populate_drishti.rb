class PopulateDrishti < ActiveRecord::Migration
  shard :all
  @app_name = "drishti"
  def self.up
  	czentrix = Integrations::Application.create(
        :name => "drishti",
        :display_name => "integrations.drishti.label",
        :description => "integrations.drishti.desc",
        :listing_order => 27,
        :options => {:direct_install => false,:keys_order => [:host_ip],
        :host_ip => { :type => :text, :required => true, :label => "integrations.drishti.host_name", 
        :info => "integrations.drishti.host_name_info"}},
        :application_type => "cti_integration",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    czentrix.save
  end

  def self.down
  	execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end
