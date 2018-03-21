class UpdateSalesforceConfig < ActiveRecord::Migration
  shard :none

  def up
    salesforce_app = Integrations::Application.find_by_name 'salesforce'
    if salesforce_app
      salesforce_app.options[:oauth_url] = "/auth/salesforce?origin=id%3D{{account_id}}%26falcon_enabled%3D{{falcon_enabled}}"
      result = salesforce_app.save
    end
  end

  def down
    salesforce_app = Integrations::Application.find_by_name 'salesforce'
    salesforce_app.options[:oauth_url] = "/auth/salesforce?origin=id%3D{{account_id}}"
    salesforce_app.save
  end
end
