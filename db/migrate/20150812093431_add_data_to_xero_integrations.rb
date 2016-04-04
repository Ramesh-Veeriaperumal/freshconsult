class AddDataToXeroIntegrations < ActiveRecord::Migration
  shard :all
  def up
    xero_app = Integrations::Application.find_by_name("xero")
    xero_app.options = {
      :direct_install => true,
      :auth_url=> "/integrations/xero/authorize", 
      :edit_url=> "/integrations/xero/edit"
    }
    xero_app.save
  end

  def down
    xero_app = Integrations::Application.find_by_name("xero")
    xero_app.options = {
      :direct_install => true,
      :auth_url=> "/integrations/xero/authorize"
    }
    xero_app.save
  end
end
