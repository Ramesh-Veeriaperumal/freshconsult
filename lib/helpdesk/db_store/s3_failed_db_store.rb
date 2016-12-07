module Helpdesk
	module DBStore
		class S3FailedDBStore < MailFailedDBStore
			extend ::NewRelic::Agent::MethodTracer
			
			FAILED_MESSAGE_PATH = "failed_messages"
			include Helpdesk::DBStore::S3DBStore
			include EnvelopeParser

			attr_accessor :bucket_name

			def initialize(bucket)
				self.bucket_name = bucket
			end

			def save_file(file_path, options)
				#throw error if account_id,other info are not present
				key_path  =  get_failed_mail_key_path(options)

				s3_options = get_s3_metadata_hash(options)
				Rails.logger.info "Failed Mail path : #{key_path} , Metadata : #{s3_options.inspect}"

				AwsWrapper::S3.upload(bucket_name, key_path, file_path, s3_options)
				return key_path
			end

			def save(content, options)
				#throw error if account_id,other info are not present
				key_path  =  get_failed_mail_key_path(options)

				s3_options = get_s3_metadata_hash(options)
				Rails.logger.info "Failed Mail path : #{key_path} , Metadata : #{s3_options.inspect}"

				AwsWrapper::S3.write_with_metadata(bucket_name, key_path, content, s3_options)
				return key_path
			end

			private

			def get_failed_mail_key_path(options)

				unique_id = options[:uid]

				received_time = options[:received_time].to_time
				date = received_time.utc.strftime("%d_%m_%Y")
				hour= received_time.utc.strftime("%H_%Z")

				key_path = "#{FAILED_MESSAGE_PATH}/#{date}/#{hour}/#{unique_id}.eml"

				return key_path
			end

			add_method_tracer :save, 'Custom/MimeController/S3_failed_save'
			
		end
	end
end