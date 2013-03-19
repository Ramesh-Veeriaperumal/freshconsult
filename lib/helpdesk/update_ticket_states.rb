module Helpdesk

	class UpdateTicketStates
		extend Va::ObserverUtil
		extend Resque::AroundPerform

		@queue = "update_ticket_states_queue"
       
		def self.perform(args)
			args.symbolize_keys!
			note = Helpdesk::Note.find args[:id]
			note.save_response_time unless note.private?
			note.trigger_observer args[:model_changes]
		end

	end
end