module Helpdesk	
	module Email
		class MailMessageProcessor
			extend ::NewRelic::Agent::MethodTracer 
			include Redis::OthersRedis
			include Redis::RedisKeys
			include EnvelopeParser
			include Helpdesk::Email::MessageProcessingUtil
			include EmailCustomLogger

			attr_accessor :raw_eml, :metadata, :ticket_params

			def initialize(queue_message)
				@message = queue_message
			end

			def execute
				Rails.logger.info "Email Fetched with metadata : #{message.except('message_attributes').inspect}"
				if message[:email_path].nil?
					msg_queue = Helpdesk::EmailQueue::MailQueueFactory.get_queue_obj(QUEUETYPE[:sqs], message[:message_attributes][:queue_name])
					msg_queue.delete_message(message[:message_attributes].with_indifferent_access)
					return
				end
				state, created_time = get_message_processing_status(message[:uid])
				process_message_by_state(state, created_time)
			ensure
				cleanup
			end

			#can be made private
			def process_message_by_state(state, created_time)
				if safe_to_process?(state, created_time)
					fetch_email
					process_message
				elsif safe_to_archive?(state, created_time)
					ticket_data = get_processed_ticket_data(message[:uid])
					fetch_email
					archive_message(ticket_data)
				elsif safe_to_delete?(state)
					cleanup_message
				end
			end

			def process_message
				Rails.logger.info "Processing the email"
				is_safe_to_process = set_processing_state(EMAIL_PROCESSING_STATE[:in_process], Time.now.utc, message[:uid])
				if is_safe_to_process
					params = get_ticket_params
					Rails.logger.info "Processed email params #{params.except(:text, :html).inspect}"
					email_logger.info "Processed Parameters: #{params.inspect}"
					params[:envelope] =  metadata[:envelope]
					spam_data = check_for_spam
					self.ticket_params = params.merge({ :spam_info => spam_data })
					ticket_data = create_ticket_or_note
					Rails.logger.info "ticket_data : #{ticket_data.inspect}"
					set_processing_state(EMAIL_PROCESSING_STATE[:finished], Time.now.utc, message[:uid])
					archive_message(ticket_data)
				end
			end

			def get_ticket_params
				Helpdesk::EmailParser::EmailProcessor.new(raw_eml).process_mail
			end

			def create_ticket_or_note
		   	process_email = Helpdesk::ProcessEmail.new(ticket_params)
		    ticket_data = process_email.perform
		    set_processed_ticket_data(ticket_data, message[:uid])
		    ticket_data
			end

			def fetch_email
				primary_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:primary])
				mail_object = primary_db.fetch(message[:email_path])
				self.raw_eml = mail_object[:eml].read if mail_object[:eml].present? # check statement validity
				self.metadata = mail_object[:metadata].with_indifferent_access
				Rails.logger.info "Primary S3 metadata : #{mail_object[:metadata].inspect}"
			end

			def archive_message(ticket_data)
				Rails.logger.info "Archiving the Email"
				email_content = StringIO.new(raw_eml)
				
				archive_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:archive])

				metadata_attributes =  get_archive_attributes(ticket_data)
				key_path = archive_db.save(email_content, metadata_attributes)
				store_archive_ticket_path(ticket_data, key_path) if key_path.present?

				set_processing_state(EMAIL_PROCESSING_STATE[:archived], Time.now.utc, message[:uid])
				cleanup_message
			end

			def store_archive_ticket_path(ticket_data, path)
				return if ticket_data[:processed_status] != PROCESSED_EMAIL_STATUS[:success]
				Rails.logger.info "Storing archive path in dynamodb"
				dynamo_obj = Helpdesk::Email::ArchiveDatastore.new
				dynamo_obj['account_id'] = ticket_data[:account_id]
				dynamo_obj['path'] = path

				if ticket_data[:note_id] != "-1"
					dynamo_obj['unique_index'] = ticket_data[:type] + "_" + ticket_data[:note_id].to_s
					dynamo_obj['ticket_id'] = ticket_data[:ticket_id]
					dynamo_obj['note_id'] = ticket_data[:note_id]
				elsif ticket_data[:article_id] != "-1"
					dynamo_obj['unique_index'] = ticket_data[:type] + "_" + ticket_data[:article_id].to_s
					dynamo_obj['article_id'] = ticket_data[:article_id]
				else
					dynamo_obj['unique_index'] = ticket_data[:type] + "_" + ticket_data[:ticket_id].to_s
					dynamo_obj['ticket_id'] = ticket_data[:ticket_id]
				end

				dynamo_obj.save
			rescue Exception => e
				Rails.logger.info "Error while storing archive path in dynamodb. #{e.message} - #{e.backtrace}"
				NewRelic::Agent.notice_error(e)
			end

			def cleanup_message
				Rails.logger.info "Deleting Email from S3 Primary path"
				primary_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:primary])
				delete_output = primary_db.delete(message[:email_path])
				unless delete_output.delete_marker #not working right now , if not fetch and check
					failed_msg_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:failed])
					failed_msg_db.delete(message[:email_path])
				end
				msg_queue = Helpdesk::EmailQueue::MailQueueFactory.get_queue_obj(QUEUETYPE[:sqs], message[:message_attributes][:queue_name])
				msg_queue.delete_message(message[:message_attributes].with_indifferent_access)
			end

			def check_for_spam
				Helpdesk::Email::SpamDetector.new.check_spam(raw_eml, metadata[:envelope])
			end

			def message
				@message
			end

			private

			def get_archive_attributes(ticket_data) #check processed time
				metadata_attributes = metadata
				metadata_attributes.merge!(Hash[ticket_data.map{ |k,v| [k, v.to_s] }])
				return metadata_attributes.with_indifferent_access
			end

			def cleanup
				self.raw_eml = nil
				self.metadata = nil
				self.ticket_params = nil
			end

			add_method_tracer :check_for_spam, 'Custom/MimeController/spam_check'
			
		end
	end
end
