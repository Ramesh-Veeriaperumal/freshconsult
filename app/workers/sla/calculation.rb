module Sla
  class Calculation < BaseWorker
    sidekiq_options :queue => :calculate_sla,
                    :retry => false,
                    :backtrace => true,
                    :failures => :exhausted

    def perform args
      args.symbolize_keys!
      ticket = Account.current.tickets.find_by_id(args[:ticket_id])

      if ticket && ticket.is_in_same_sla_state?(args[:sla_state_attributes])
        ticket.update_sla = true
        ticket.sla_calculation_time = args[:sla_calculation_time]
        ticket.save
      end
    end
  end
end
