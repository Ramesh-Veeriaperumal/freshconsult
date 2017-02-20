class PopulateDynamicsV2 < ActiveRecord::Migration
  shard :all
  def up
    dynamics_v2 = Integrations::Application.create(
      :name => "dynamics_v2",
      :display_name => "integrations.dynamics_v2.label",
      :description => "integrations.dynamics_v2.desc",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
      :listing_order => 47,
      :options => {
        :install => {:require_feature => {:notice => 'integrations.dynamics_v2.no_feature', :feature_name => :dynamics_v2}},
        :edit => {:require_feature => {:notice => 'integrations.dynamics_v2.no_feature', :feature_name => :dynamics_v2}},
        :direct_install => true, 
        :auth_url => "/integrations/sync/crm/settings?state=dynamics_v2", 
        :edit_url => "/integrations/sync/crm/edit?state=dynamics_v2&method=put",
        :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }},
      :application_type => "dynamics_v2")
  end

  def down
    Integrations::Application.find_by_name("dynamics_v2").destroy
  end

end
