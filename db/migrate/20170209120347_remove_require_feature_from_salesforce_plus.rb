class RemoveRequireFeatureFromSalesforcePlus < ActiveRecord::Migration
  def up
    application = Integrations::Application.find_by_name("salesforce_v2")
    application.options = {
      :direct_install => true, 
      :oauth_url => "/auth/salesforce_v2?origin=id%3D{{account_id}}", 
      :edit_url => "/integrations/sync/crm/edit?state=salesforce_v2&method=put",
      :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }
    }
    application.save!
  end

  def down
    application = Integrations::Application.find_by_name("salesforce_v2")
    application.options = {
      :install => {:require_feature => {:feature_name => :salesforce_v2}},
      :edit => {:require_feature => {:feature_name => :salesforce_v2}},
      :direct_install => true, 
      :oauth_url => "/auth/salesforce_v2?origin=id%3D{{account_id}}", 
      :edit_url => "/integrations/sync/crm/edit?state=salesforce_v2&method=put",
      :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }
    }
    application.save!
  end
end
