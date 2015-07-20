# Used for updating the company for tickets in reports
class Workers::Reports::UpdateTicketsCompany
  
  include Sidekiq::Worker
  
  sidekiq_options :queue => :update_tickets_company, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    user_id = args[:user_id]
    user = Account.current.all_users.find_by_id(user_id)
    return unless user
    model_changes = args[:changes]
    Sharding.run_on_slave do
      user.tickets.includes(associations_include).find_in_batches(:batch_size => 300) do |tickets|
        tickets.each do |ticket|
          ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY, 
                            {:model_changes => model_changes})
        end
      end
    end
  end
  
  def associations_include
    [ {:flexifield => [:flexifield_def]}, :ticket_states, :schema_less_ticket, :requester, :group, :responder]
  end
    
end
