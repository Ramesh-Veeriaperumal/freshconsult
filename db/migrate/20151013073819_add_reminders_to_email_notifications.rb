class AddRemindersToEmailNotifications < ActiveRecord::Migration

	shard :all
  
  def up
	Account.find_in_batches(:batch_size => 300) do |accounts|
		accounts.each do |account|
			begin
				account.make_current
				email_notifications = [{
		            :notification_type => 22, 
					:account_id => account.id, 
					:requester_notification => false, 
					:agent_notification => account.email_notifications.find_by_notification_type(EmailNotification::FIRST_RESPONSE_SLA_VIOLATION).agent_notification?,
					:agent_template => '<p> Hi,
						<br><br>Response is due for ticket #{{ticket.id}}.<br><br>Ticket Details: <br><br>Subject - {{ticket.subject}}<br><br>
							Requestor - {{ticket.requester.email}}<br><br>Ticket link - {{ticket.url}}<br><br>
							This is an reminder email from {{helpdesk_name}}</p>',
					:agent_subject_template => 'Response due for {{ticket.subject}}'
		          },
		          {
		            :notification_type => 23, 
					:account_id => account.id, 
					:requester_notification => false, 
					:agent_notification => account.email_notifications.find_by_notification_type(EmailNotification::RESOLUTION_TIME_SLA_VIOLATION).agent_notification?,
					:agent_template => '<p>Hi,
						<br><br>Resolution time for ticket #{{ticket.id}} is fast approaching. The ticket is due by {{ticket.due_by_hrs}}.<br><br>
						Ticket Details: <br><br>Subject - {{ticket.subject}}<br><br>Requestor - {{ticket.requester.email}}<br><br>Ticket link - {{ticket.url}}<br><br>
						This is an escalation reminder email from {{helpdesk_name}}</p>',
					:agent_subject_template => 'Resolution expected for  {{ticket.subject}}'
		          }]
	          
	          	email_notifications.each do |email_notification|
	            	notification = account.email_notifications.build(email_notification)
	            	notification.save
            	end
            rescue Exception => e
          		p e
        	ensure
         		Account.reset_current_account
       	 	end
		end
	end

  end

  def down
  	Sharding.run_on_all_shards do
      EmailNotification.delete_all(["notification_type in (?)", [22, 23]])
    end
  end

end

