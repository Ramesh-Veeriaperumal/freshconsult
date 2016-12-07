module Helpdesk
	module DBStore
		class S3ArchiveDBStore < MailArchiveDBStore
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
				key_path = nil
				unless options[:processed_status] ==  PROCESSED_EMAIL_STATUS[:duplicate]
					key_path  =  get_archive_key_path(options)
					s3_options = get_s3_metadata_hash(options)
					Rails.logger.info "Archive path : #{key_path} , Metadata : #{s3_options.inspect}"
					AwsWrapper::S3.upload(bucket_name, key_path, file_path, s3_options)
				end
				return key_path
			rescue => e
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Error while saving archiving email : #{e.message} - #{e.backtrace}"
			end

			def save(content, options)
				#throw error if account_id,other info are not present
				key_path = nil
				unless options[:processed_status] ==  PROCESSED_EMAIL_STATUS[:duplicate]
					key_path  =  get_archive_key_path(options)
					s3_options = get_s3_metadata_hash(options)
					Rails.logger.info "Archive path : #{key_path} , Metadata : #{s3_options.inspect}"
					AwsWrapper::S3.write_with_metadata(bucket_name, key_path, content, s3_options)
				end
				return key_path
			rescue => e
				raise Helpdesk::Email::Errors::EmailDBSaveError, "Error while saving archiving email : #{e.message} - #{e.backtrace}"
			end

			private

			def get_archive_key_path(options)
				#throw error if account_id,other info are not present
				account_id = options[:account_id].to_s

				envelope_to = get_to_address_from_envelope(options[:envelope])
				envelope_to_address = envelope_to.first

				received_time = options[:received_time].to_time.utc
				date = received_time.strftime("%d_%m_%Y")
				hour= received_time.strftime("%H_%Z")

				#to decide  filename later
				ticket_id = options[:ticket_id].to_s
				note_id = options[:note_id].to_s
				article_id = options[:article_id].to_s
				type = options[:type].to_s
				processed_status = options[:processed_status]

				key_path = ""

				if processed_status == PROCESSED_EMAIL_STATUS[:success]
					hour_path = "#{account_id}/#{envelope_to_address}/#{date}/#{hour}"
					filename =""
					if type == PROCESSED_EMAIL_TYPE[:ticket]
						filename = "#{ticket_id}/#{type}_#{ticket_id}.eml"
					elsif type == PROCESSED_EMAIL_TYPE[:note]
						filename = "#{ticket_id}/#{type}_#{note_id}.eml"
					elsif type == PROCESSED_EMAIL_TYPE[:article]
						filename = "#{type}/#{type}_#{article_id}.eml"
					elsif type == PROCESSED_EMAIL_TYPE[:invalid]
						filename = "#{type}/#{options[:uid]}.eml"
					end
					key_path = "#{hour_path}/#{filename}"
				else
					#do other cases
					key_path = "#{FAILED_EMAIL_PATH}/#{options[:uid]}.eml"
				end

				return key_path
			end

			add_method_tracer :save, 'Custom/MimeController/s3_archive_save'
			
		end
	end
end
