module Sla
  class Calculation < BaseWorker
    sidekiq_options :queue => :calculate_sla,
                    :retry => false,
                    :failures => :exhausted

    def perform args
      args.symbolize_keys!
      # Setting thread variable to restrict requeue of this job beyond a fixed number of retries
      Thread.current[:ticket_sla_calculation_retries] = args[:retries]
      ticket = Account.current.tickets.find_by_id(args[:ticket_id])

      if ticket && ticket.is_in_same_sla_state?(args[:sla_state_attributes])
        ticket.update_sla = true
        ticket.sla_calculation_time = args[:sla_calculation_time]
        ticket.save
      end
    end
  end
end
