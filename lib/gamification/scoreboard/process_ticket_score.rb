module Gamification
	module Scoreboard
		class ProcessTicketScore < Resque::FreshdeskBase
			@queue = "gamificationQueue"

			def self.perform(args)
				args.symbolize_keys!
				id, account_id = args[:id], args[:account_id]
				ticket = Helpdesk::Ticket.find_by_id_and_account_id(id, account_id)
				args[:remove_score] ? remove_score(ticket) : add_score(ticket, args)
			end

			def self.add_score(ticket, args)
				SupportScore.add_support_score(ticket, 
							ScoreboardRating.resolution_speed(ticket, args[:resolved_at_time]))
    		SupportScore.add_fcr_bonus_score(ticket) if args[:fcr]
			end

			def self.remove_score(ticket)
				SupportScore.destroy_all(:account_id => ticket.account_id,  
							:scorable_type => "Helpdesk::Ticket", :scorable_id => ticket.id, 
        			:score_trigger => Gamification::Scoreboard::Constants::TICKET_CLOSURE)
			end

		end
	end
end