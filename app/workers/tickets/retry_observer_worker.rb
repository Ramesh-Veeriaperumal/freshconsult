module Tickets
  class RetryObserverWorker < ObserverWorker
    sidekiq_options queue: :retry_observer, retry: 0, failures: :exhausted

    def perform(args)
      args.symbolize_keys!
      Rails.logger.info "Retrying observer::TicketID::#{args[:ticket_id]}"
      super
    end
  end
end
