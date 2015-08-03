class AddAfterDestroyQuickbooksApp < ActiveRecord::Migration

  shard :all

  def up
  	application = Integrations::Application.find_by_name_and_account_id('quickbooks', 0)
  	application.options = {
      :direct_install => true,
      :after_destroy => {
      	:clazz => "Integrations::QuickbooksUtil",
      	:method => "remove_app_from_qbo"
      }
    }
    application.save!
  end

  def down
  	application = Integrations::Application.find_by_name_and_account_id('quickbooks', 0)
  	application.options = {
	   :direct_install => true,
	   :oauth_url => "/auth/quickbooks?origin=id%3D{{account_id}}"
    }
    application.save!
  end
end