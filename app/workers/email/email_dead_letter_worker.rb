require 'newrelic_rpm'

module Email
	class EmailDeadLetterWorker

		include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
		include Shoryuken::Worker
		include Helpdesk::Email::MessageProcessingUtil

		shoryuken_options queue: SQS[:email_dead_letter_queue], auto_delete: false, body_parser: :json,  batch: false

		def perform(sqs_msg, args)
			Rails.logger.info "Dead Letter Queue params : #{args.inspect}"
			begin
				#return if check_failed_status(sqs_msg, args['uid'])
				current_state, created_time = get_message_processing_status(args['uid'])
				unless failed_state?(current_state)
					primary_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:primary])
					email_obj = fetch_email(primary_db, args['email_path'])
					push_s3_failed_messages(email_obj, current_state)
					delete_email_in_primary(primary_db, args['email_path'])
					failed_state = get_failed_state(current_state)
					set_processing_state(failed_state, Time.now.utc, args['uid'])
				end
				sqs_msg.delete
			rescue Helpdesk::Email::Errors::EmailDBRecordNotFound
				sqs_msg.delete
				Rails.logger.info "S3 key not found. Deleting email from dead letter queue"
			rescue => e
				Rails.logger.info "Error in EmailDeadLetterWoker : #{e.message} - #{e.backtrace}"
				NewRelic::Agent.notice_error(e, {:description => "Error in EmailDeadLetterWorker"})
			end
		end

		def get_failed_state(state)
			if state == EMAIL_PROCESSING_STATE[:finished].to_s
				return EMAIL_PROCESSING_STATE[:archive_failed]
			else
				return EMAIL_PROCESSING_STATE[:processing_failed]
			end
		end

		def fetch_email(primary_db, path)
			Rails.logger.info "Fetching Email from S3 primary path"
			primary_db.fetch(path)
		end

		def push_s3_failed_messages(email_obj, state)
			failed_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:failed])
			options = get_failed_attributes(email_obj, state)
			email_content = StringIO.new(email_obj[:eml].read)
			failed_db.save(email_content, options)
			Rails.logger.info "Saved to S3 Failed path - Metadata : #{email_obj[:metadata].inspect}"
			NewRelic::Agent.notice_error(Exception.new("Failed to process one email"),{:description => "Email Metadata : #{email_obj[:metadata].inspect}"})
		end

		def get_failed_attributes(email_obj, state) 
				metadata_attributes = email_obj[:metadata]
				
				additional_metadata = {
					:failed_state => get_failed_state(state).to_s,
					:failed_time => "#{Time.now.utc}"
				}
				
				metadata_attributes.merge!(additional_metadata)
				return metadata_attributes.with_indifferent_access
		end

		def delete_email_in_primary(primary_db, path)
			primary_db.delete(path)
			Rails.logger.info "Deleted from S3 primary path"
		end
		
		add_transaction_tracer :perform, :category => :task
	end
end
