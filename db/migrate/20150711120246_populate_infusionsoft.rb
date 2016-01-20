class PopulateInfusionsoft < ActiveRecord::Migration
  shard :all
  def up
    infusionsoft = Integrations::Application.create(
        :name => "infusionsoft",
        :display_name => "integrations.infusionsoft.label",
        :description => "integrations.infusionsoft.desc",
        :listing_order => 40,
        :options => {
        	:direct_install => true,  
        	:edit_url => "infusionsoft/edit",
        	:oauth_url => "/auth/infusionsoft?origin=id%3D{{account_id}}", 
        	:default_fields => {:contact => ["First Name"], :account => ["Company"]}
        	},     
        :application_type => "infusionsoft",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
  end

  def down
    execute("DELETE FROM applications WHERE name='infusionsoft'")
  end
end
