class Reports::BuildNoActivity < BaseWorker
  
  sidekiq_options :queue => :reports_no_activity, :retry => 0, :backtrace => true, :failures => :exhausted
  
  include Helpdesk::Ticketfields::TicketStatus
  
  def perform(args)
    args.symbolize_keys!
    account = Account.current
    return unless account
    current_date = Time.zone.parse(args[:date].to_s).utc
    Sharding.run_on_slave do
      account.tickets.use_index("index_helpdesk_tickets_account_id_and_status").unresolved.where(conditions(current_date)).
                        includes(associations_include).
                        find_in_batches(:batch_size => 300) do |tickets|
        tickets.each do |ticket|
          ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY, {:manual_publish => true})
        end
      end
    end
    # account.account_additional_settings.additional_settings[:last_no_activity_date] = current_date.strftime("%Y-%m-%d")
    # account.account_additional_settings.save
  end
  
  def conditions(date)
    dates = []
    (84..90).each{ |d| dates << [(Time.now - d.days), d] }

    conditions        = ["spam = false AND deleted = false AND DATEDIFF(?, created_at) > 83 AND (" + (["DATEDIFF(?, created_at) % ? = 0"] * 7).join(' OR ') + ")",
                            Time.now, dates.flatten
                        ].flatten
  end
  
  def associations_include
    [ {:flexifield => [:flexifield_def]}, :ticket_states, :schema_less_ticket, :requester, :group, :responder]
  end
  
end
