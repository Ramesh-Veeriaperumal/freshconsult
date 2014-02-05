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
			begin
				fetch_details(args)
				if @call.recording_audio.blank?
					download_data
					build_recording_audio
					create_voicemail_ticket(args) if args[:voicemail] && @call.recording_audio
					release_data
				else
					Rails.logger.debug "Duplicate job for freshfone record attachment  for 
					account => #{@account.id} call sid => #{@call.call_sid}"
				end
			rescue Exception => e
				Rails.logger.debug "Error in processing queued freshfone call 
						recording :: \n#{e.message}\n#{e.backtrace.join("\n\t")}"
				NewRelic::Agent.notice_error(e, {:description => "Freshfone CallRecordingAttachments job 
					failed call_sid => #{@call.call_sid} :: account => #{@account.id} "})
				release_data
			end
		end

		private

			def self.fetch_details(args)
					@account = Account.current
					@call = @account.freshfone_calls.find_by_id(args[:call_id])
					@file_url = @call.recording_url + ".mp3"
					@file_name = args[:call_sid]
			end

			def self.download_data
				@data = RemoteFile.new(@file_url,'','',@file_name)
				NewRelic::Agent.notice_error( 
							StandardError.new("Freshfone Call Recording Attachment size => #{ @data.size} exceeds 40MB 
								: account => #{@account.id} : call sid => #{call.call_sid} ")) if @data.size > 40.megabyte
			end

			def self.build_recording_audio
				@call.build_recording_audio(:content => @data).save
			end

			def self.create_voicemail_ticket(args)
					set_current_call(@call)
					voicmail_ticket(args)
			end

			def self.release_data
				return unless @data
				@data.unlink_open_uri
				@data.unlink
			end
	end
end
