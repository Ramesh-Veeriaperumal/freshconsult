class PopulateCzentrix < ActiveRecord::Migration
  shard :all
  @app_name = "czentrix"
  def self.up
  	czentrix = Integrations::Application.create(
        :name => "czentrix",
        :display_name => "integrations.czentrix.label",
        :description => "integrations.czentrix.desc",
        :listing_order => 26,
        :options => {:direct_install => false,:keys_order => [:host_ip],
        :host_ip => { :type => :text, :required => true, :label => "integrations.czentrix.host_name", 
        :info => "integrations.czentrix.host_name_info"}},
        :application_type => "cti_integration",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    czentrix.save
  end

  def self.down
  	execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end
