module SandboxHelper

	def send_error_notification(error, account)
	  topic = SNS["sandbox_notification_topic"]
	  subj = "Sandbox Error in Account: #{account.id}"
	  message = "Sandbox failure in Account id: #{account.id}, \n#{error.message}\n#{error.backtrace.join("\n\t")}"
	  DevNotification.publish(topic, subj, message.to_json)
	end
end