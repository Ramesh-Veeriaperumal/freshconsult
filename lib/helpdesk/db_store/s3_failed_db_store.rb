module Helpdesk
	module DBStore
		class S3FailedDBStore < MailFailedDBStore
			extend ::NewRelic::Agent::MethodTracer
			
			include Helpdesk::DBStore::S3DBStore
			include Helpdesk::Email::Constants
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

				failed_type =  options[:is_permanent] == "true" ? "Permanent" : "Retry"

				Rails.logger.info "#{failed_type} Failed Mail path : #{key_path} , Metadata : #{s3_options.inspect}"

				AwsWrapper::S3.write_with_metadata(bucket_name, key_path, content, s3_options)
				return key_path
			end

			private

			def get_failed_mail_key_path(options)

				unique_id = options[:uid]

				received_time = options[:received_time].to_time
				#date = received_time.utc.strftime("%d_%m_%Y")
				date = received_time.utc.strftime("%Y_%m_%d")
				hour= received_time.utc.strftime("%H_%Z")

				if options[:is_permanent]
					failed_path_prefix = PERMANENT_FAILED_MESSAGE_PATH
				else
					failed_path_prefix = RETRY_FAILED_MESSAGE_PATH
				end

				key_path = "#{failed_path_prefix}/#{date}/#{hour}/#{unique_id}.eml"

				return key_path
			end

			add_method_tracer :save, 'Custom/MimeController/S3_failed_save'
			
		end
	end
end