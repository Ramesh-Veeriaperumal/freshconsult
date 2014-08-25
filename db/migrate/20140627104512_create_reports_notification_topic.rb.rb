class CreateReportsNotificationTopic < ActiveRecord::Migration
  shard :all
  def self.up
    name = SNS["reports_notification_topic"]
    recepients = ["arvind@freshdesk.com", "hari@freshdesk.com"]
    backup = true
    DevNotification.create_dev_notification_topic(name, recepients, backup)
  end

  def self.down
    name = SNS["social_notification_topic"]
    DevNotification.delete_dev_notification_topic(name)
  end
end
