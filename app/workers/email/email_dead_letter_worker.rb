module Email
	class EmailDeadLetterWorker

		include Shoryuken::Worker
		include Helpdesk::Email::MessageProcessingUtil

		shoryuken_options queue: SQS[:email_dead_letter_queue], auto_delete: false, body_parser: :json,  batch: false

		def perform(sqs_msg, args)
			Rails.logger.info "Dead Letter Queue params : #{args.inspect}"
			begin
				return if check_failed_status(sqs_msg, args['uid'])
				primary_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:primary])
				email_obj = fetch_email(primary_db, args['email_path'])
				push_s3_failed_messages(email_obj)
				delete_email_in_primary(primary_db, args['email_path'])
				set_processing_state(EMAIL_PROCESSING_STATE[:failed], Time.now.utc, args['uid'])
				sqs_msg.delete
			rescue Helpdesk::Email::Errors::EmailDBRecordNotFound
				sqs_msg.delete
				Rails.logger.info "S3 key not found. Deleting email from dead letter queue"
			rescue => e
				Rails.logger.info "Error in EmailDeadLetterWoker : #{e.message}"
			end
		end

		def check_failed_status(sqs_msg, uid)
			state, created_time = get_message_processing_status(uid)
			failed_status = (state == EMAIL_PROCESSING_STATE[:failed].to_s) ? true : false
			sqs_msg.delete if failed_status
			failed_status
		end

		def fetch_email(primary_db, path)
			Rails.logger.info "Fetching Email from S3 primary path"
			primary_db.fetch(path)
		end

		def push_s3_failed_messages(email_obj)
			failed_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:failed])
			options = email_obj[:metadata]
			email_content = StringIO.new(email_obj[:eml].read)
			failed_db.save(email_content, options.with_indifferent_access)
			Rails.logger.info "Saved to S3 Failed path"
		end

		def delete_email_in_primary(primary_db, path)
			primary_db.delete(path)
			Rails.logger.info "Deleted from S3 primary path"
		end
		
	end
end
