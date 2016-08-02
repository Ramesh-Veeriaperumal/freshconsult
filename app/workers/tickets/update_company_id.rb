class Tickets::UpdateCompanyId < BaseWorker
  
  sidekiq_options :queue => :update_tickets_company_id, 
                  :retry => 2, 
                  :backtrace => true, 
                  :failures => :exhausted

  include RabbitMq::Helper

  TICKET_TYPES = ["tickets", "archive_tickets"]
  TICKET_LIMIT = 100

  def perform(args)
    args.symbolize_keys!
    user_ids = args[:user_ids]
    company_id = args[:company_id]
    old_company_id = args[:old_company_id]
    TICKET_TYPES.each do |tkts|
      company_id_in_query = old_company_id || company_id
      condition = company_id ? "(owner_id != ? OR owner_id IS NULL)" : "owner_id is not ?"
      condition = "owner_id = ?" if old_company_id

      Account.current.send(tkts).where(["requester_id in (?) AND #{condition}", 
                                          user_ids, company_id_in_query]).find_in_batches(:batch_size => TICKET_LIMIT) do |tickets|
        Account.current.send(tkts).where("id in (?)", tickets.map(&:id)).update_all(:owner_id => company_id)
        execute_on_db { send_updates_to_rmq(tickets, tickets[0].class.name) } if tkts == "archive_tickets"
        execute_on_db { subscribers_manual_publish(tickets) } if tkts == "tickets"

        #=> Needing this to publish to search until another way found.
        execute_on_db { tickets.map(&:sqs_manual_publish) }
      end
    end
  end

  def subscribers_manual_publish(items)
    items.each do |item|
      item.manual_publish_to_rmq("update", RabbitMq::Constants.const_get("RMQ_REPORTS_COUNT_TICKET_KEY"), {:manual_publish => true})
    end
  end
end
