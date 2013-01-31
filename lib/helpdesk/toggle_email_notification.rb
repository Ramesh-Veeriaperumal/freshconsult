module Helpdesk::ToggleEmailNotification

	def disable_notification(account = current_account)
    	Thread.current["notifications_#{account.id}"] = EmailNotification::DISABLE_NOTIFICATION   
  	end

	def disable_user_activation(account = current_account)
    	Thread.current["notifications_#{account.id}"] = {EmailNotification::USER_ACTIVATION => {:requester_notification => false}}
  	end

  	def enable_notification(account = current_account)
    	Thread.current["notifications_#{account.id}"] = nil
  	end

end