class UpdateShopifyAppForMarketplace < ActiveRecord::Migration
  
  shard :all

  def up
    application = Integrations::Application.find_by_name('shopify')
    application.options[:no_settings] = true
    application.options[:after_commit_on_create] = { :clazz => "Integrations::ShopifyUtil", 
      :method => "update_remote_integrations_mapping" }
    application.options[:after_commit_on_destroy] = { :clazz => "Integrations::ShopifyUtil",
      :method => "remove_remote_integrations_mapping" }
    application.options[:install_action] = { :url => { :controller => 'integrations/marketplace/shopify', :action => 'install' },
      :html => {:method => 'put'} }
    application.save!
  end

  def down
    application = Integrations::Application.find_by_name('shopify')
    application.options = application.options.except(:no_settings, :after_commit_on_create, :after_commit_on_destroy, :install_action)
    application.save!
  end
end
