class UpdateEmailNotifications < ActiveRecord::Migration
  def self.up
  	Account.all.each do |account|
  		    e = account.email_notifications.find_by_notification_type(EmailNotification::PASSWORD_RESET)
  		    template = '<p>A request to reset your password has been made.If you did not make this request, simply ignore this email. If you did make this request, just click the link below:<br />{{password_reset_url}}<br />If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br />Regards,<br />{{helpdesk_name}}</p>'  		    
				if e.agent_template == template 
					e.update_attributes(:agent_template => 'Hey {{agent.name}},<br />
							A request to change your password has been made.<br />
							To reset your password, click on the link below:<br />
							<a href="{{password_reset_url}}">Click here to reset the password.</a> <br /><br />
							If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br /><br />
							Regards,<br />{{helpdesk_name}}')

				end
				
				if e.requester_template == template 

					e.update_attributes(:requester_template => 'Hey {{agent.name}},<br />
						A request to change your password has been made.<br />
						To reset your password, click on the link below:<br />
						<a href="{{password_reset_url}}">Click here to reset the password.</a> <br /><br />
						If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br /><br />
						Regards,<br />{{helpdesk_name}}' )
				end
	end
  end

  def self.down
  	Account.all.each do |account|
  		    e = account.email_notifications.find_by_notification_type(EmailNotification::PASSWORD_RESET)

			e.update_attributes(:agent_template => '<p>A request to reset your password has been made.If you did not make this request, simply ignore this email. If you did make this request, just click the link below:<br />{{password_reset_url}}<br />If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br />Regards,<br />{{helpdesk_name}}</p>', 
				:requester_template =>  '<p>A request to reset your password has been made.If you did not make this request, simply ignore this email. If you did make this request, just click the link below:<br />{{password_reset_url}}<br />If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.<br />Regards,<br />{{helpdesk_name}}</p>')
	end


  end
end
