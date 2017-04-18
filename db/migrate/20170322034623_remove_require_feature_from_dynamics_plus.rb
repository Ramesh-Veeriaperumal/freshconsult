class RemoveRequireFeatureFromDynamicsPlus < ActiveRecord::Migration
	shard :all
  def up
    application = Integrations::Application.find_by_name("dynamics_v2")
    application.options = {
    	:direct_install => true,
      :auth_url => "/integrations/sync/crm/settings?state=dynamics_v2",
      :edit_url => "/integrations/sync/crm/edit?state=dynamics_v2&method=put",
      :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }
    }
    application.save!
  end

  def down
  	application = Integrations::Application.find_by_name("dynamics_v2")
    application.options = {
    	:direct_install => true,
      :install => {:require_feature => {:notice => 'integrations.dynamics_v2.no_feature', :feature_name => :dynamics_v2}},
      :edit => {:require_feature => {:notice => 'integrations.dynamics_v2.no_feature', :feature_name => :dynamics_v2}},
      :auth_url => "/integrations/sync/crm/settings?state=dynamics_v2",
      :edit_url => "/integrations/sync/crm/edit?state=dynamics_v2&method=put",
      :after_commit_on_destroy => { :clazz => "IntegrationServices::Services::CloudElementsService", :method => "uninstall" }
    }
    application.save!
  end
end