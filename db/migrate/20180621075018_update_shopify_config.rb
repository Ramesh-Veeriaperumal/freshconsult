class UpdateShopifyConfig < ActiveRecord::Migration
  shard :all

  def up
    shopify_app = Integrations::Application.find_by_name 'shopify'
    if shopify_app
      shopify_app.options[:edit_url] = "/integrations/marketplace/shopify/edit"
      result = shopify_app.save
    end
  end

  def down
    shopify_app = Integrations::Application.find_by_name 'shopify'
    if shopify_app
      shopify_app.options[:edit_url] = nil
      result = shopify_app.save
    end
  end
end
