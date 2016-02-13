class MergeTicketsAttachments < BaseWorker
	sidekiq_options :queue => :merge_tickets_attachments, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(args)
		args.symbolize_keys!
		account = Account.current
		source_ticket = account.tickets.find_by_id(args[:source_ticket_id])
		target_ticket = account.tickets.find_by_id(args[:target_ticket_id])
		source_description_note = target_ticket.notes.find_by_id(args[:source_description_note_id])
		return if (source_ticket.blank? || source_description_note.blank?) 
		source_ticket.attachments.each do |attachment|      
			url = attachment.authenticated_s3_get_url
			io = open(url)
			if io 
				def io.original_filename; base_uri.path.split('/').last.gsub("%20"," "); end
			end
			source_description_note.attachments.build(:content => io, :description => "", :account_id => account) 
		end
		source_ticket.cloud_files.each do |cloud_file|
			source_description_note.cloud_files.build({:url => cloud_file.url, :application_id => cloud_file.application_id, :filename => cloud_file.filename })
		end
		source_description_note.save_note
	end
end