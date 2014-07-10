class EmailNotificationAgent < ActiveRecord::Base
  
  belongs_to :email_notification
  belongs_to :user
  belongs_to :account
  
  validates_uniqueness_of :user_id, :scope => :email_notification_id
  
  attr_protected :account_id, :user_id
  
end
