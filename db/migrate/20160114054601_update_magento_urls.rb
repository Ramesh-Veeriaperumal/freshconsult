class UpdateMagentoUrls < ActiveRecord::Migration

	shard :all

  def up
  	application = Integrations::Application.find_by_name('magento')
    application.options[:auth_url] = "/integrations/magento/new"
    application.options[:edit_url] = "/integrations/magento/edit"
    application.save!
  end

  def down
  	application = Integrations::Application.find_by_name('magento')
    application.options[:auth_url] = "magento/new"
    application.options[:edit_url] = "magento/edit"
    application.save!
  end
end
