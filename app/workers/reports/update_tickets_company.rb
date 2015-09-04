# Used for updating the company for tickets in reports
class Reports::UpdateTicketsCompany < BaseWorker
  
  sidekiq_options :queue => :update_tickets_company, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    user_id = args[:user_id]
    user = Account.current.all_users.find_by_id(user_id)
    return unless user
    model_changes = args[:changes]
    Sharding.run_on_slave do
      
      # Manual publish for normal tickets
      user.tickets.includes(ticket_associations_include).find_in_batches(:batch_size => 300) do |tickets|
        tickets.each do |ticket|
          ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY, 
                            {:model_changes => model_changes})
        end
      end
      
      # Manual publish for archive tickets
      user.archive_tickets.includes(archive_associations_include).find_in_batches(:batch_size => 300) do |archive_tickets|
        archive_tickets.each do |archive_ticket|
          archive_ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_ARCHIVE_TICKET_KEY, 
                            {:model_changes => model_changes})
        end
      end
    end
  end
  
  def ticket_associations_include
    [ {:flexifield => [:flexifield_def]}, :ticket_states, :schema_less_ticket, :requester, :group, :responder]
  end
  
  def archive_associations_include
    [ {:flexifield => [:flexifield_def]}, :archive_ticket_association, :requester, :group, :responder]
  end
    
end