class AddOptionsToSalesforceIntegrationApp < ActiveRecord::Migration
  
  shard :none
  
  def self.up
	application =  Integrations::Application.find_by_name_and_account_id('salesforce',0)
	application.options.merge!({:pre_install=>true})
	application.save!
  end

  def self.down
	application =  Integrations::Application.find_by_name_and_account_id('salesforce',0)
	application.options.except!(:pre_install)
	application.save!
  end
end
