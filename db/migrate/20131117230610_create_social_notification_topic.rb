class CreateSocialNotificationTopic < ActiveRecord::Migration
  shard :all
  def self.up
    name = SNS["social_notification_topic"]
    recepients = ["arvind@freshdesk.com", "revathi@freshdesk.com", "sumankumar@freshdesk.com"]
    backup = true
    DevNotification.create_dev_notification_topic(name, recepients, backup)
  end

  def self.down
    name = SNS["social_notification_topic"]
    DevNotification.delete_dev_notification_topic(name)
  end
end
