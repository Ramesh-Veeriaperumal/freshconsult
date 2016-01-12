class Tickets::UpdateCompanyId < BaseWorker
  
  sidekiq_options :queue => :update_tickets_company_id, 
                  :retry => 2, 
                  :backtrace => true, 
                  :failures => :exhausted

  include RabbitMq::Helper

  TICKET_TYPES = ["tickets", "archive_tickets"]
  TICKET_LIMIT = 500

  def perform(args)
    args.symbolize_keys!
    user_ids = args[:user_ids]
    company_id = args[:company_id]
    TICKET_TYPES.each do |tkts|
      last_ticket_id = nil
      begin
        condition = company_id ? "(owner_id != ? OR owner_id IS NULL)" : "owner_id is not ?"
        # Not using find_in_batches `cause of inability to update_all an array
        condition << " AND id > #{last_ticket_id}" if last_ticket_id
        tickets = Account.current.send(tkts).where(["requester_id in (?) AND #{condition}", 
                                                 user_ids, company_id]).limit(TICKET_LIMIT)
        if execute_on_db { tickets.count } > 0
          last_ticket_id = execute_on_db { tickets.last.id if tickets.last }
          updated_tickets = tickets.update_all(:owner_id => company_id)
          execute_on_db { send_updates_to_rmq(tickets, tickets.klass.name) }
        end
      end while updated_tickets == TICKET_LIMIT
    end
  end
end
