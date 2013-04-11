module Helpdesk

	class UpdateTicketStates
		extend Resque::AroundPerform

		@queue = "update_ticket_states_queue"
       
		def self.perform(args)
			account = Account.current
			User.current = account.users.find_by_id args[:current_user_id]

			note = Helpdesk::Note.find args[:id]
			note.save_response_time unless note.private?
			note.trigger_observer(args[:model_changes])
		end

	end
end