module Helpdesk

	class UpdateTicketStates
		extend Resque::AroundPerform

		@queue = "update_ticket_states_queue"
       
		def self.perform(args)
			begin
				account = Account.current
				User.current = account.users.find_by_id args[:current_user_id]
				note = Helpdesk::Note.find args[:id]
				note.save_response_time unless note.private?
			rescue Exception => e
				puts e.inspect, args.inspect
				NewRelic::Agent.notice_error(e, {:args => args})
			ensure
				note.trigger_observer(args[:model_changes])
			end
		end

	end
end