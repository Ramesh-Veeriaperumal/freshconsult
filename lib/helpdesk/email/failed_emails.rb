module Helpdesk
	module Email
		class FailedEmails

			include Helpdesk::Email::Constants
			extend Helpdesk::Email::MessageProcessingUtil

			MAX_FAILED_RETRY_ATTEMPT = 20

			def self.retry_failed_email(email_metadata)
				attempt, last_retry_time = get_message_retry_status(email_metadata[:uid])
				attempt = attempt.to_i
				if attempt < MAX_FAILED_RETRY_ATTEMPT
					if can_retry_now?(attempt, last_retry_time)
						Rails.logger.info "Retrying failed email , attempt:#{attempt} : #{email_metadata.inspect}"
						set_retry_attempt((attempt+ 1), Time.now.utc, email_metadata[:uid])
						process_failed_email(email_metadata)
					end
				else
					move_to_permanent_failed_path(email_metadata)
				end
			end

			def self.process_failed_email(email_metadata)
				start = Time.now
			    begin
			        email_metadata = email_metadata.with_indifferent_access
			        params = email_metadata.merge(:is_failed_retry => true)
			        Timeout.timeout(300) do
			        	mmp = Helpdesk::Email::MailMessageProcessor.new(params)
			        	mmp.execute
			        end
			        Rails.logger.info "Sucessfully prpocessed mail from failed path : #{params.inspect}"
			    rescue => e
			        Rails.logger.info "Failed to process mail from failed path - #{e.message} - #{e.backtrace}"
			    ensure
			        elapsed_time = (Time.now - start).round(3)
			        Rails.logger.info "Time taken for processing failed email : #{elapsed_time} seconds - UID : #{params[:uid]} path - #{params[:email_path]} "
			    end
			end

			def self.move_to_permanent_failed_path(email_metadata)
				failed_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:failed])
				email_obj = failed_db.fetch(email_metadata[:email_path])

				state, created_time = get_message_processing_status(email_metadata[:uid])
				unless permanent_failed_state?(state)
					push_s3_failed_messages(email_obj)
					set_processing_state(EMAIL_PROCESSING_STATE[:permanent_failed], Time.now.utc, email_metadata[:uid])
				end

				failed_db.delete(email_metadata[:email_path])
				Rails.logger.info "Primary S3 metadata : #{mail_object[:metadata].inspect}"

			end


			def self.get_failed_attributes(email_obj) 
				metadata_attributes = email_obj[:metadata]
				additional_metadata = {
					:is_permanent => "true",
					:permanent_failed_time => "#{Time.now.utc}"
				}
				metadata_attributes.merge!(additional_metadata)
				return metadata_attributes.with_indifferent_access
			end


			def self.push_s3_failed_messages(email_obj)
				failed_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:failed])
				options = get_failed_attributes(email_obj)
				email_content = StringIO.new(email_obj[:eml].read)
				failed_db.save(email_content, options)
				Rails.logger.info "Saved to S3 Permanent Failed path - Metadata : #{email_obj[:metadata].inspect}"
				NewRelic::Agent.notice_error(Exception.new("Cannot process email "),{:description => "Email Metadata : #{email_obj[:metadata].inspect}"})
			end
			
		end
	end
end