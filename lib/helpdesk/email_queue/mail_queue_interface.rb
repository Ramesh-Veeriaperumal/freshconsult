module Helpdesk	
	module EmailQueue
		class MailQueueInterface

			def get_queue_attributes
				raise NotImplementedError
			end

			def send_message(msg)
				raise NotImplementedError
			end

			def send_message_batch(msgs, attributes)
				raise NotImplementedError
			end

			def delete_message(msg)
				raise NotImplementedError
			end

			def delete_message_batch(msgs)
				raise NotImplementedError
			end
		end
	end
end
