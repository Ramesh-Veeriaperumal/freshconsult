class PopulateDynamicsCrmSync < ActiveRecord::Migration
  shard :all
  def up
  	dynamics_crm_sync => integrations::Application.create(
	    :name => "dynamics_crm_sync",
	    :display_name => "integrations.dynamics_crm_sync.label",
	    :description => "integrations.dynamics_crm_sync.desc",
	    :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
	    :listing_order => 44,
	    :options => {
	    	:direct_install => true, 
        :auth_url => "/integrations/sync/crm/settings?state=dynamics_crm_sync", 
        :edit_url => "/integrations/sync/crm/edit?state=dynamics_crm_sync&method=put",
        :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }},
	    :application_type => "dynamics_crm_sync")
  end
  end

  def down
  end
end
