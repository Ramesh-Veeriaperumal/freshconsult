module Helpdesk
	module Email
		class RetryEmailWorker

			include Helpdesk::Email::Constants
			extend Helpdesk::Email::MessageProcessingUtil

			MAX_FAILED_RETRY_ATTEMPT = 20

			def self.retry_failed_emails
				failed_emails_metadata = get_failed_emails_metadata
				run_available_failed_emails(failed_emails_metadata)
			end

			def self.run_available_failed_emails(failed_emails_metadata)
				failed_emails_metadata.each do |metadata_with_key|
					metadata_with_key = metadata_with_key.with_indifferent_access
					metadata = metadata_with_key[:metadata]
					set_current_processing_status(metadata) # to handle old failed emails
					metadata_attributes = { :uid => metadata["uid"], :email_path => metadata_with_key["key"] }
					params = metadata_attributes.merge(:message_attributes => nil)
					FailedEmails.retry_failed_email(params)
				end
			end

			def self.get_failed_emails_metadata(date = nil)
				failed_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:failed])
				sorted_items = []
				if date.present?
					path_to_fetch = "#{RETRY_FAILED_MESSAGE_PATH}/#{date}"
				else
					path_to_fetch = "#{RETRY_FAILED_MESSAGE_PATH}"
				end
				items = failed_db.list_object_metadata(path_to_fetch) # optimise list object metadata call
				sorted_items = items.sort_by{|i| i[:metadata]["received_time"].to_time.to_i }
				return sorted_items
			end

			def self.set_current_processing_status(metadata)
				state, created_time = get_message_processing_status(metadata[:uid])
				if state.blank?
					old_state = metadata[:failed_state]
					set_processing_state(old_state.to_i, Time.now.utc, metadata[:uid])
				end
			end
						
		end
	end
end