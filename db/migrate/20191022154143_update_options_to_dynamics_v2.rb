class UpdateOptionsToDynamicsV2 < ActiveRecord::Migration
  shard :all
  
  def up
    dynamics_app = Integrations::Application.find_by_name 'dynamics_v2'
    if dynamics_app
      dynamics_app.options[:auth_url] = '/a/integrations/sync/crm/settings?state=dynamics_v2'
      dynamics_app.save!
    end
  end

  def down
  	dynamics_app = Integrations::Application.find_by_name 'dynamics_v2'
  	dynamics_app.options[:auth_url] = '/integrations/sync/crm/settings?state=dynamics_v2'
  	dynamics_app.save!
  end
end
