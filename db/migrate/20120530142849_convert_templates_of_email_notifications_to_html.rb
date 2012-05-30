class ConvertTemplatesOfEmailNotificationsToHtml < ActiveRecord::Migration
  def self.up
  	  	Account.all.each do |account|
     	account.email_notifications.each do |notification|
  	 		if (notification.version == 1)
      			notification.requester_template = (RedCloth.new(notification.requester_template).to_html) if notification.requester_template
      			notification.agent_template = (RedCloth.new(notification.agent_template).to_html) if notification.agent_template
    			notification.version =2
    		end
    		notification.save
  		end
  	end
  end

  def self.down
  end
end
