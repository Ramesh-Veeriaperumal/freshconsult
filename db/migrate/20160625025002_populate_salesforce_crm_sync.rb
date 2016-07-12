class PopulateSalesforceCrmSync < ActiveRecord::Migration
  shard :all
  def up
  	salesforce_crm_sync = Integrations::Application.create(
  		:name => "salesforce_crm_sync"
    	:display_name => "integrations.salesforce_crm_sync.label"
    	:description => "integrations.salesforce_crm_sync.desc" 
    	:account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    	:listing_order => 43
    	:options => {
    		:direct_install => true, 
        :oauth_url => "/auth/salesforce_crm_sync?origin=id%3D{{account_id}}", 
        :edit_url => "/integrations/sync/crm/edit?state=salesforce_crm_sync&method=put",
        :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }}
    	:application_type => "salesforce_crm_sync")
  end

  def down
  	Integrations::Application.find_by_name("salesforce_crm_sync").destroy
  end
end
