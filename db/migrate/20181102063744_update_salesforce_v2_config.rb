class UpdateSalesforceV2Config < ActiveRecord::Migration
  shard :none

  def up
    salesforce_plus_app = Integrations::Application.find_by_name 'salesforce_v2'
    if salesforce_plus_app
      salesforce_plus_app.options[:oauth_url] = "/auth/salesforce?origin=id%3D{{account_id}}%26falcon_enabled%3D{{falcon_enabled}}"
      result = salesforce_plus_app.save
    end
  end

   def down
    salesforce_plus_app = Integrations::Application.find_by_name 'salesforce_v2'
    salesforce_plus_app.options[:oauth_url] = "/auth/salesforce?origin=id%3D{{account_id}}"
    salesforce_plus_app.save
  end
end
