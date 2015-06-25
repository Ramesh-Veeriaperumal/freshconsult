class Workers::ClearTrash
  extend Resque::AroundPerform

  @queue = 'clear_trash_worker'

  def self.perform(args)
    begin
      account =  Account.current
      if args[:empty_trash]
        max_display_id = account.get_max_display_id
        account.tickets.find_in_batches(:conditions => ['deleted = true and display_id < ?', max_display_id]) do |tickets|
          clear_ticket(tickets)
        end
      else
        account.tickets.find_in_batches(:joins => "INNER JOIN helpdesk_schema_less_tickets 
                                    ON helpdesk_tickets.id=helpdesk_schema_less_tickets.ticket_id
                                    AND helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id", 
          :conditions => {"helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.trashed_column}" => 1}) do |batches|
          clear_ticket(batches)
        end
      end
    rescue Exception => e
      puts "something is wrong in clear trash: #{e.message}"
      puts e.backtrace.join("\n\t")
    ensure
      if args[:empty_trash]
        key = "EMPTY_TRASH_TICKETS:#{account.id}" 
        $redis_tickets.del key
      end
    end
  end

  def self.clear_ticket(tickets)
    tickets.each do |ticket|
      ticket.destroy
    end
  end
end
