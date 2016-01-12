module Gamification
	module Scoreboard
		class ProcessTicketScore 
			extend Resque::AroundPerform
			@queue = "gamificationQueue"

			def self.perform(args)
				args.symbolize_keys!
				id, account_id = args[:id], args[:account_id]
				
				if args[:remove_score]
					remove_score(args)
				else
					ticket = Helpdesk::Ticket.find_by_id_and_account_id(id, account_id)
					if ticket
						add_score(ticket, args)
					else
						puts "Ticket was deleted before processing score :: Ticket ID : #{id}, Account ID : #{account_id}"
					end
				end
			end

			def self.add_score(ticket, args)
				SupportScore.add_support_score(ticket, 
							ScoreboardRating.resolution_speed(ticket, args[:resolved_at_time]))
    		SupportScore.add_fcr_bonus_score(ticket) if args[:fcr]
			end

			def self.remove_score(args)
				SupportScore.destroy_all(:account_id => args[:account_id],  
							:scorable_type => "Helpdesk::Ticket", :scorable_id => args[:id], 
        			:score_trigger => Gamification::Scoreboard::Constants::TICKET_CLOSURE)
			end

		end
	end
end