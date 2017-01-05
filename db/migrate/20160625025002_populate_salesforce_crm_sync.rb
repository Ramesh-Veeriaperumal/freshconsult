class PopulateSalesforceCrmSync < ActiveRecord::Migration
  shard :all
  def up
    salesforce_v2 = Integrations::Application.create(
      :name => "salesforce_v2",
      :display_name => "integrations.salesforce_v2.label",
      :description => "integrations.salesforce_v2.desc",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
      :listing_order => 43,
      :options => {
        :install => {:require_feature => {:feature_name => :salesforce_v2}},
        :edit => {:require_feature => {:feature_name => :salesforce_v2}},
        :direct_install => true, 
        :oauth_url => "/auth/salesforce_v2?origin=id%3D{{account_id}}", 
        :edit_url => "/integrations/sync/crm/edit?state=salesforce_v2&method=put",
        :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }},
      :application_type => "salesforce_v2")
  end

  def down
    Integrations::Application.find_by_name("salesforce_v2").destroy
  end
end
