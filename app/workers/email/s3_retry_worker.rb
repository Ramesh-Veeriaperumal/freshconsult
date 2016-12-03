class Email::S3RetryWorker < BaseWorker

	sidekiq_options :queue => 's3_retry_worker', :retry => false, :backtrace => true

	include Helpdesk::Email::MessageProcessingUtil
	include EnvelopeParser

	attr_accessor :key_path, :metadata, :hourly_path

	def perform(args)
		Rails.logger.info "Retry process for path: #{args['hourly_path']}"
		self.hourly_path = args['hourly_path']
		return unless update_process_state
		@primary_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:primary])
		pending_emails_in_path = false
		RANDOM_S3_CHAR_CONFIG[:random_s3_char].each do |hex_char|
			prefix = "#{hex_char}/#{hourly_path}"
			Rails.logger.info "Prefix path: #{prefix}"
			object_list = @primary_db.list_object_metadata(prefix)
			object_list.each do |s3object|
				begin
					Rails.logger.info "Processing for S3 key: #{s3object[:key]}"
					pending_emails_in_path = true
					self.key_path = s3object[:key]
					fetch_metadata(s3object[:metadata])
					state, created_time = get_message_processing_status(metadata[:uid])
					process_message_by_state(state, created_time)
					Rails.logger.info "Processing completed for S3 path: #{s3object[:key]}"
				rescue => e
					Rails.logger.info "Error in S3 retry worker. #{e.message} - #{e.backtrace}"
					Rails.logger.info "Processing pending for S3 path: #{s3object[:key]}"
				ensure
					delete_path_info
				end
			end
		end
		Rails.logger.info "Any Pending emails to work on the path #{hourly_path} : #{pending_emails_in_path}"
		cleanup_process_data(pending_emails_in_path)
	end

	def email_hourly_path
		@email_hourly_path ||= Helpdesk::EmailHourlyUpdate.find_by_hourly_path(hourly_path)
	end

	def update_process_state
		unless email_hourly_path.present?
			Rails.logger.info "No Record found for Helpdesk::EmailHourlyUpdate"
			return false
		end
		email_hourly_path.update_attributes(:state => "Retry")
	end

	def fetch_metadata(metadata_attributes)
		self.metadata = metadata_attributes.with_indifferent_access
	end

	def process_message_by_state(state, created_time)
		if safe_to_process?(state, created_time)
			requeue_mail
		elsif safe_to_archive?(state, created_time)
			archive_message
		elsif safe_to_delete?(state)
			delete_message
		end
	end

	def requeue_mail
		Rails.logger.info "Pushing into SQS from Retry Worker"
		metadata_attributes = { :uid => metadata[:uid], :email_path => key_path }
		domain = get_domain_from_envelope(metadata[:envelope])
		Sharding.select_shard_of(domain) do
			account = Account.find_by_full_domain(domain)
			queue_type = (account.present? && account.subscription.present? ? account.subscription.state : 'default')
			sqs_queue = Helpdesk::EmailQueue::MailQueueFactory.get_queue_obj(QUEUETYPE[:sqs], EMAIL_QUEUE[queue_type])
			sqs_queue.send_message(metadata_attributes.to_json)
		end
	rescue ShardNotFound 
		Rails.logger.info "ShardNotFound Error. Pushing to default queue"
		sqs_queue = Helpdesk::EmailQueue::MailQueueFactory.get_queue_obj(QUEUETYPE[:sqs], EMAIL_QUEUE['default'])
		sqs_queue.send_message(metadata_attributes.to_json)
	rescue Exception => e
		Rails.logger.info "Enqueue to SQS failed. #{e.message} - #{e.backtrace}"
	end
	
	def archive_message
		Rails.logger.info "Archiving Email from Retry worker"
		s3_options = get_archive_attributes
		return if s3_options.empty?
		archive_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:archive])
		raw_eml = @primary_db.fetch(key_path)[:eml].read
		email_content = StringIO.new(raw_eml)
		archive_db.save(email_content, s3_options.with_indifferent_access)
		set_processing_state(EMAIL_PROCESSING_STATE[:archived], Time.now, metadata[:uid])
		delete_message
	end

	def delete_message
		Rails.logger.info "Deleting Email from Retry worker"
		@primary_db.delete(key_path)
	end

	def get_archive_attributes
		ticket_data = get_processed_ticket_data(metadata[:uid])
		return {} if ticket_data.nil? or ticket_data.empty?
		ticket_data.merge!(metadata)
	end

	def delete_path_info
		self.key_path = nil
		self.metadata = nil
	end

	def cleanup_process_data(pending_emails)
		Rails.logger.info "Releasing the lock for the path in retry worker"
		email_hourly_path.unlock
		delete_hourly_path unless pending_emails
		self.hourly_path = nil
	end

	def delete_hourly_path
		email_hourly_path.delete if email_hourly_path.present?
		Rails.logger.info "Deleted EmailHourlyUpdate with path #{hourly_path}"
	end

end
