module Gamification
    class ProcessTicketScore < BaseWorker
      include Sidekiq::Worker
      sidekiq_options :queue => "gamification_ticket_score" , :retry => 0, :dead => true, :failures => :exhausted
      
      def perform(args)
        args.symbolize_keys!
        ticket = Gamification::Scoreboard::Ticket.new(args)
        if args[:remove_score]
          ticket.remove_score(args)
        else
          ticket.add_score(args)
        end
      rescue Exception => e
        puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(e, {:custom_params => {:description => "Error occoured while gamification process ticket score in sidekiq"}})
      end
    end  
end