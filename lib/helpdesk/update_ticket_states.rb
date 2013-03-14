module Helpdesk
	class UpdateTicketStates 
		extend Resque::AroundPerform
		@queue = "update_ticket_states_queue"
       
		def self.perform(args)
			args.symbolize_keys!
			note = Helpdesk::Note.find_by_id(args[:id])
			note.save_response_time
		end

	end
end