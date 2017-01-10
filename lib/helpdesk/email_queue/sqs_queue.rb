module Helpdesk	
	module EmailQueue
		class SqsQueue < EmailQueue::MailQueueInterface

			class EmailQueueError < StandardError
			end

			attr_accessor :queue_url, :queue_name

			def initialize(queue_name)
				self.queue_name = queue_name
				self.queue_url = AwsWrapper::SqsV2.queue_url(@queue_name)
			end

			def get_queue_attributes
				AwsWrapper::SqsV2.queue_attributes(queue_name)
			rescue => e 
				raise EmailQueueError, "Error while getting attributes from SQS queue #{e.message} -#{e.backtrace}"
			end

			def send_message(msg, attributes = {})
				AwsWrapper::SqsV2.send_message(queue_name, msg, 0, attributes)
			rescue => e
				Rails.logger.info e.class
				raise EmailQueueError, "Error while sending the email through sqs queue #{e.message} - #{e.backtrace}"
			end

			def send_message_batch(msgs, attributes = {})
				$sqs_v2_client.send_message_batch({queue_url: queue_url, entries: msgs, delay_seconds: 0, message_attributes: attributes})
			rescue => e
				raise EmailQueueError, "Error while sending batch emails through SQS queue #{e.message} - #{e.backtrace}"
			end

			def delete_message(msg_attributes)
				result = $sqs_v2_client.delete_message({queue_url: queue_url, receipt_handle: msg_attributes[:receipt_handle]})
				Rails.logger.info "Message Deleted From SQS" if result.successful?
			rescue => e
				raise EmailQueueError, "Error while deleting email from SQS queue #{e.message} - #{e.backtrace}"
			end

			def delete_message_batch(sqs_msgs)
				$sqs_v2_client.delete_message_batch({queue_url: queue_url, entries: sqs_msgs})
			rescue => e
				raise EmailQueueError, "Error while deleting batches of email from SQS queue #{e.message} - #{e.backtrace}"
			end
		end
	end
end
