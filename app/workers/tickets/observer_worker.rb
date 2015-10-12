module Tickets
  class ObserverWorker < BaseWorker

    sidekiq_options :queue => :ticket_observer, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform args
      begin
        account = Account.current
        evaluate_on = account.tickets.find_by_id args["ticket_id"]
        doer = account.users.find_by_id args["doer_id"]        
        current_events = args["current_events"].symbolize_keys
        Thread.current[:observer_doer_id] = doer.id

        if evaluate_on.present? and doer.present?
          account.observer_rules_from_cache.each do |vr|
            vr.check_events doer, evaluate_on, current_events
          end
          evaluate_on.save!
        else
          puts "Skipping observer worker for : Account id:: #{Account.current.id}, Ticket id:: #{args['ticket_id']}, User id:: #{args['doer_id']}"            
        end
      rescue => e
        puts "Something is wrong Observer : Account id:: #{Account.current.id}, Ticket id:: #{args['ticket_id']}, #{e.message}"
        NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
        raise e
      ensure
        Thread.current[:observer_doer_id] = nil
      end
    end
  end
end