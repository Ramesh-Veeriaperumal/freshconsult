module Helpdesk
	module DBStore
		class S3PrimaryDBStore < MailPrimaryDBStore
			extend ::NewRelic::Agent::MethodTracer
			include Helpdesk::DBStore::S3DBStore
			include Helpdesk::Email::Constants
			
			attr_accessor :bucket_name

			def initialize(bucket)
				self.bucket_name = bucket
			end

			def get_hourly_key_path(received_host, received_time, is_random = false)
				key_path = ""
				current_hour_timestamp = received_time.to_time.utc.strftime("%d_%m_%Y_%H_%Z")
				# s3_random_prefix = is_random ? get_random_s3_prefix : DUMMY_RANDOM_S3_PREFIX
				if is_random
					s3_random_prefix = get_random_s3_prefix
					key_path = s3_random_prefix + "/" + current_hour_timestamp + "/" + received_host
				else
					key_path = current_hour_timestamp + "/" + received_host
				end
				return key_path
			end

			def save_file(file_path, options)
				#throw error if received_host is not present
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Received host field cannot be blank" if options[:received_host].blank?
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Received time field cannot be blank" if options[:received_time].blank?

				received_host = options[:received_host]
				received_time = options[:received_time]
				key_path, unique_id  =  get_unique_key_path(received_host, received_time)

				uid_hash = {
					"uid" => "#{unique_id}",
					"received_host" => "#{received_host}"
				}

				options.merge!(uid_hash)
				s3_options = get_s3_metadata_hash(options)
				Rails.logger.info "Primary save path : #{key_path} , Metadata : #{s3_options.inspect} "

				AwsWrapper::S3.upload(bucket_name, key_path, file_path, s3_options)
				return key_path, unique_id
			rescue => e
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Error while saving email to primary DB : #{e.message} - #{e.backtrace}"
			end

			def save(content, options)
				#throw error if received_host is not present
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Received host field cannot be blank" if options[:received_host].blank?
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Received time field cannot be blank" if options[:received_time].blank?
				
				received_host = options[:received_host]
				received_time = options[:received_time]
				key_path, unique_id  =  get_unique_key_path(received_host, received_time)

				uid_hash = {
					"uid" => "#{unique_id}",
					"received_host" => "#{received_host}"
				}

				options.merge!(uid_hash)
				s3_options = get_s3_metadata_hash(options)
				Rails.logger.info "Primary save path : #{key_path} , Metadata : #{s3_options.inspect} "

				AwsWrapper::S3.write_with_metadata(bucket_name, key_path, content, s3_options)
				return key_path, unique_id
			rescue => e
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Error while saving email to primary DB : #{e.message} - #{e.backtrace}"
			end

			private

			def get_unique_key_path(received_host, received_time)
				unique_id = SecureRandom.uuid
				hourly_path = get_hourly_key_path(received_host, received_time, true)
				key_path =  hourly_path + "/" + unique_id + ".eml"
				return key_path, unique_id
			end

			def get_random_s3_prefix
				RANDOM_S3_CHAR_CONFIG[:random_s3_char][Random::DEFAULT.rand(NO_OF_RANDOM_S3_PREFIX)]
			end

			add_method_tracer :save, 'Custom/MimeController/s3_primary_save'
			
		end
	end
end
