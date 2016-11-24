class UpdateSlackCallbackUrls < ActiveRecord::Migration
  shard :all

  def up
    application = Integrations::Application.find_by_name('slack_v2')
     application.options[:after_create] = {:method => "add_slack", :clazz => "IntegrationServices::Services::SlackService"}
     application.options[:after_destroy] = {:method => "remove_slack", :clazz => "IntegrationServices::Services::SlackService"}
    application.save!
  end

  def down
    application = Integrations::Application.find_by_name('slack_v2')
    application.options.slice!(:after_create, :after_destroy)
    application.save!
  end
end
