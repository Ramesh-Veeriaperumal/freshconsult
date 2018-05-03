module Gamification
  module Scoreboard
    class Ticket 

      def initialize(args)
        @ticket = Account.current.tickets.find(args[:id])
      end

      def add_score(args)
        return if @ticket.blank?
        SupportScore.add_support_score(@ticket, 
          ScoreboardRating.resolution_speed(@ticket, args[:resolved_at_time]))
        SupportScore.add_fcr_bonus_score(@ticket) if args[:fcr]
      end

      def remove_score(args)
        Account.current.support_scores.where( :scorable_type => "Helpdesk::Ticket", :scorable_id => args[:id], 
          :score_trigger => Gamification::Scoreboard::Constants::TICKET_CLOSURE).destroy_all
      end
    end   
  end
end