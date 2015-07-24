class Reports::BuildNoActivity < BaseWorker
  
  sidekiq_options :queue => :reports_no_activity, :retry => 0, :backtrace => true, :failures => :exhausted
  
  include Helpdesk::Ticketfields::TicketStatus
  
  def perform(args)
    args.symbolize_keys!
    account = Account.current
    return unless account
    current_date = Time.zone.parse(args[:date].to_s).utc
    Sharding.run_on_slave do
      account.tickets.where(conditions(current_date)).
                        includes(associations_include).
                        find_in_batches(:batch_size => 300) do |tickets|
        tickets.each do |ticket|
          ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY, {:model_changes => {:no_activity => []}})
        end
      end
    end
    # account.account_additional_settings.additional_settings[:last_no_activity_date] = current_date.strftime("%Y-%m-%d")
    # account.account_additional_settings.save
  end
  
  def conditions(date)
    last_updated_time = (date - 60.days)
    conditions        = [" updated_at >=  ? AND updated_at <= ? AND status not in (?)" ,
                            last_updated_time.beginning_of_day, last_updated_time.end_of_day, [RESOLVED, CLOSED]
                        ]
  end
  
  def associations_include
    [ {:flexifield => [:flexifield_def]}, :ticket_states, :schema_less_ticket, :requester, :group, :responder]
  end
  
end
