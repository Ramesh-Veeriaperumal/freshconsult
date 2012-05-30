class PopulateVersionToEmailNotifications < ActiveRecord::Migration
  def self.up
  	Account.all.each do |account|
     account.email_notifications.each do |notification|
 		notification.version = 1
 		notification.save
     end
 	end
  end

  def self.down
  end
end
