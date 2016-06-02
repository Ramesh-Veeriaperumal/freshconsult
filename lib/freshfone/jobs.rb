module Freshfone::Jobs
  QUEUE = "freshfone_default_queue"
  
	class FoneJobs 
		extend Resque::AroundPerform

		def self.perform(args)
			perform_job(args) 
		end
	end

	class CallBilling < FoneJobs
		@queue = QUEUE


		def self.perform_job(args)
			calculator = Freshfone::CallCostCalculator.new(args, Account.current)
			calculator.perform
		end
		# VVERBOSE=1 QUEUE=FRESHFONE_QUEUE rake resque:work
	end

	class CallQueuing < FoneJobs
		@queue = 'freshfone_queue_wait'
		def self.perform_job(args)
			queue_worker = Freshfone::Jobs::CallQueueWorker.new
			queue_worker.perform(args)
		end
	end
	
	class AttachmentsDelete < FoneJobs
		@queue = QUEUE

		def self.perform_job(args)
			account = Account.current
			attachments = account.attachments.find_all_by_id(args[:attachment_ids])
			attachments.each { |attachment| attachment.destroy }
		end
	end

	class CallRecordingAttachment < FoneJobs
		@queue = "freshfone_attachment_queue"
		extend Freshfone::CallHistory
		extend Freshfone::TicketActions
		
		def self.perform_job(args)
			@data = nil
			fetch_details(args)
			unless @call.recording_deleted
				begin
					if @call.recording_audio.present?
						Rails.logger.debug "Duplicate job for freshfone record attachment  for 
						account => #{@account.id} call sid => #{@call.call_sid}"
						return
					end
					fetch_twilio_recording
					if @skip_attempt.present? #preventing the job for recordings which are not found
						Rails.logger.debug "Recording Not Found For Account :: #{@account.id}, Call :: #{@call.call_sid}"
						return
					end
					#Ignoring recordings of duration less than 5 seconds
					if @recording_duration.to_i < 5
					 	@call.recording_url = nil
					 	@call.save
					 	@recording.delete
					else
						set_status_voicemail if args[:voicemail]
						download_data
						build_recording_audio
					end
				rescue Exception => e
					if args[:attempt].present?
						NewRelic::Agent.notice_error(e, {:description => "Freshfone CallRecordingAttachments job 
							failed call_sid => #{@call.call_sid} :: account => #{@account.id} :: 
							recording_sid => #{@recording_sid} :: attempt #{args[:attempt]}"})
						raise e if (args[:attempt] == 2)
					end				
					attempt = args[:attempt].present? ? (args[:attempt]+1) : 1
					Resque::enqueue_at((attempt * 15).minutes.from_now, Freshfone::Jobs::CallRecordingAttachment, 
						args.merge!({:attempt => attempt}))
				ensure
					release_data
				end
			end
			create_voicemail_ticket(args) if args[:voicemail] && @call.recording_audio
		end

		private

			def self.fetch_details(args)
				@account = Account.current
				@call = @account.freshfone_calls.find_by_id(args[:call_id])
				@file_url = @call.recording_url + ".mp3" unless @call.recording_deleted
				@file_name = args[:call_sid]
			end

			def self.fetch_twilio_recording
				@recording_sid = File.basename(@call.recording_url)
				@recording = @call.account.freshfone_subaccount.recordings.get(File.basename(@recording_sid))
				@recording_duration = @recording.duration
			rescue => e
				if e.respond_to?(:code) && e.code == 20404
					@skip_attempt = true
				else
					 raise e
				end
			end

			def self.download_data
				begin
					@data = RemoteFile.new(@file_url,'','',"#{@file_name}.mp3").fetch
				rescue OpenURI::HTTPError => e
					Rails.logger.error "Error in in Call Recording attachment Job Account Id: #{@account.id} Call id: #{@call.id}\n Exception: #{e.message}\n Stacktrace: #{e.backtrace.join('\n\t')}"
					raise e if e.io.status.present? && e.io.status[0] != '404' # preventing retry of recordings which are not found
				end
				NewRelic::Agent.notice_error( 
						StandardError.new("Freshfone Call Recording Attachment size => #{ @data.size} exceeds 40MB 
								: account => #{@account.id} : call sid => #{@call.call_sid} ")) if @data.present? && @data.size > 40.megabyte
			end

			def self.build_recording_audio
				@call.build_recording_audio(:content => @data).save if @data.present?
			end

			def self.set_status_voicemail     
 				@call.update_status({:DialCallStatus => "voicemail"})
 				@call.save
 			end

			def self.create_voicemail_ticket(args)
				set_current_call(@call)
				voicmail_ticket(args) if @call.ticket.blank?
			end

			def self.release_data
				return unless @data

				begin
					@data.unlink_open_uri
					@data.unlink
				rescue
					Rails.logger.debug "Error in freshfone record attachment  for 
					account => #{@account.id} call sid => #{@call.call_sid} raise from release_data"
				end
			end
	end
end
