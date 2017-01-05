module Helpdesk
	module Email
		#Handles storing email in primary storage and sending them through the mailQueue for processing 
		class EmailHandler < Struct.new(:params)
			
			include Redis::OthersRedis
			include Redis::RedisKeys
			include EnvelopeParser
			include Helpdesk::Email::Constants

			@@hourly_email_path = nil

			def execute
				save_email
			end

			private

			def save_email

				# Check other possible ways to do this
				# Create temp eml file for the email
				email_content = StringIO.new(params[:email])
				
				# do s3 activities
				primary_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:primary])

				envelope_to_array = get_to_address_from_envelope(params[:envelope])

				envelope_to_array.each_with_index do |to_address, i|

					envelope_params = ActiveSupport::JSON.decode(params[:envelope]).with_indifferent_access
					envelope_params[:to] = Array.new.push(to_address)
					params[:envelope] = envelope_params.to_json
					metadata_attributes =  get_supporting_attributes
					current_hour_email_path = primary_db.get_hourly_key_path(metadata_attributes[:received_host], metadata_attributes[:received_time])
					register_hourly_email_path(metadata_attributes, current_hour_email_path)
					key_path, unique_id = primary_db.save(email_content, metadata_attributes)
					Rails.logger.info "Saved path : #{key_path} , Unique_id : #{unique_id} \n"
					send_message(to_address, key_path, unique_id) 

				end

			end

			def get_supporting_attributes

				#to decide whether account_id is required
				metadata_attributes = {
					:received_time => "#{Time.now.utc}",
					:received_host => "#{Socket.gethostname}",
					:envelope => params[:envelope]
					# :from => params[:from]
				}

				return metadata_attributes
			end

			def register_hourly_email_path(metadata_attributes, current_hour_email_path)
				unless email_path_registered?(metadata_attributes, current_hour_email_path)
					set_hourly_email_path(current_hour_email_path)
					begin
						Helpdesk::EmailHourlyUpdate.create({:hourly_path => "#{current_hour_email_path}",
						 :received_host => "#{metadata_attributes[:received_host]}", :state  => "Initial Create" })
					rescue ActiveRecord::RecordNotUnique => e
						Rails.logger.info "#{e.message}"
					rescue Exception => e
						set_hourly_email_path(nil)
						raise e
					end
				end
			end

			def email_path_registered?(metadata_attributes, current_hour_email_path)
				hourly_email_path.present? && (current_hour_email_path == hourly_email_path)
			end

			def hourly_email_path
				@@hourly_email_path
			end

			def set_hourly_email_path(current_hour_email_path)
				@@hourly_email_path = current_hour_email_path
			end

			def send_message(to_envelope, key_path, unique_id)
				metadata_attributes = { :uid => unique_id, :email_path => key_path, 
					:msg_uuid => Thread.current[:message_uuid].try(:first) }
				domain = parse_email_with_domain(to_envelope)[:domain]
				Sharding.select_shard_of(domain) do
					account = Account.find_by_full_domain(domain)
					queue_type = (account.present? && account.subscription.present? ? account.subscription.state : 'default')
					sqs_queue = Helpdesk::EmailQueue::MailQueueFactory.get_queue_obj(QUEUETYPE[:sqs], EMAIL_QUEUE[queue_type])
					sqs_queue.send_message(metadata_attributes.to_json)
					Rails.logger.info "Email pushed into the queue: #{EMAIL_QUEUE[queue_type]}"
				end
			rescue Exception => e
				Rails.logger.info "Enqueue to SQS failed. #{e.message} - #{e.backtrace}"
			end

		end
	end
end
