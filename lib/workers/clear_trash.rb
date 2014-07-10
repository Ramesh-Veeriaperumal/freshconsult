class Workers::ClearTrash
  extend Resque::AroundPerform

  @queue = 'clear_trash_worker'

  def self.perform(args)
    begin
      account =  Account.current
      account.tickets.find_in_batches(:joins => "INNER JOIN helpdesk_schema_less_tickets 
                                ON helpdesk_tickets.id=helpdesk_schema_less_tickets.ticket_id
                                    AND helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id", 
          :conditions => {"helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.trashed_column}" => 1}) do |batches|
          batches.each do |item|
           item.destroy
          end
      end
    rescue Exception => e
      puts "something is wrong: #{e.message}"
    rescue
      puts "something went wrong"
    end
  end
end