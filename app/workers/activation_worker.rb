class ActivationWorker < BaseWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :activation_worker, :retry => 1, :backtrace => true, :failures => :exhausted

 def perform 
    
    notifications = Account.current.email_notifications
   # make all agent related notifications true except ticket created upon activation
    notifications.select{|n| n.visible_to_agent? && n.notification_type != EmailNotification::NEW_TICKET}.each do |n|
   	n.update_attribute(:agent_notification,true)
   end
   # make all requested related notifications true upon activation
    notifications.select{|n|  !n.visible_only_to_agent?}.each do |n|
   	n.update_attribute(:requester_notification,true)
   end
   
 end
end