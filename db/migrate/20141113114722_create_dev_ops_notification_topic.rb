class CreateDevOpsNotificationTopic < ActiveRecord::Migration
  shard :all
  def self.up
    name = SNS["dev_ops_notification_topic"]
    recepients = Rails.env.production? ? Helpdesk::EMAIL[:production_dev_ops_email] : "dev-ops@freshpo.com"
    backup = true
    DevNotification.create_dev_notification_topic(name, recepients, backup)
  end

  def self.down
    name = SNS["dev_ops_notification_topic"]
    DevNotification.delete_dev_notification_topic(name)
  end
end
