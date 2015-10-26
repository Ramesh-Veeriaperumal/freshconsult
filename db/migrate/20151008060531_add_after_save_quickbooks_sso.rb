class AddAfterSaveQuickbooksSso < ActiveRecord::Migration

  shard :all

  def up
  	application = Integrations::Application.find_by_name('quickbooks')
  	application.options[:after_create] = { :clazz => "Integrations::QuickbooksUtil",
  	  :method => "add_remote_integrations_mapping" }
  	application.save!
  end

  def down
  	application = Integrations::Application.find_by_name('quickbooks')
  	application.options.delete(:after_create)
  	application.save!
  end
end
