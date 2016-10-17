class Helpdesk::TicketFields::UpdateTicketFilter < BaseWorker

  sidekiq_options :queue => :update_ticket_filter, :retry => 1, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account     = Account.current
    conditions  = args[:conditions]

    account.ticket_filters.each do |filter|
      updated = false
      conditions.each { |condition|
        condition.symbolize_keys!
        replace_key   = condition[:replace_key]
        condition_key = condition[:condition_key]

        updated = true if filter.update_condition(condition_key, replace_key)
      }
      filter.save if updated
    end

  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

end