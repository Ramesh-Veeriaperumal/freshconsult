class Tickets::UpdateCompanyId < BaseWorker
  sidekiq_options queue: :update_tickets_company_id,
                  retry: 2,
                  failures: :exhausted

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
      condition = company_id ? "owner_id is null" : "owner_id is not null"
      condition = "owner_id = ?" if old_company_id

      execute_on_db {
        Account.current.safe_send(tkts).where(["requester_id in (?) AND #{condition}",
                                            user_ids]).find_in_batches(:batch_size => TICKET_LIMIT) do |tickets|

          #company id is explicitly updated to avoid reload for tickets.
          ticket_ids = tickets.inject([]) { |tkt_ids, tkt| tkt.company_id = company_id; tkt_ids << tkt.id }
          execute_on_db("run_on_master") {
            Account.current.safe_send(tkts).where("id in (?)", ticket_ids).update_all(:owner_id => company_id)
          }
          if company_id.present?
            @updates_hash = { company_id: ['*', company_id] }
            send_updates_to_rmq(tickets, tickets[0].class.name) if tkts == "archive_tickets"
            subscribers_manual_publish(tickets) if tkts == "tickets"

            #=> Needing this to publish to search until another way found.
            tickets.map(&:sqs_manual_publish)
          end
        end
      }
    end
  end

  def subscribers_manual_publish(items)
    key = 'RMQ_REPORTS_COUNT_TICKET_KEY'
    items.each do |item|
      item.manual_publish(["update", RabbitMq::Constants.const_get(key), {:manual_publish => true}], [:update, { model_changes: @updates_hash }])
    end
  end
end
