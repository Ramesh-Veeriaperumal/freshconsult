module Helpdesk	
	module EmailQueue
		class MailQueueFactory

			def self.get_queue_obj(type, queue_name)
				if type.eql?(:sqs)
					SqsQueue.new(queue_name)
				else
					raise NotImplementedError
				end
			end
		end
	end
end
