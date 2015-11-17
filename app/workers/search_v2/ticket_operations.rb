class SearchV2::TicketOperations < SearchV2::IndexOperations
  
  class UpdateCompany < SearchV2::TicketOperations
    def perform(args)
      args.symbolize_keys!
      user = Account.current.all_users.find(args[:user_id])
      user_tickets = user.tickets
      user_tickets.each do |ticket|
        ticket.send(:update_search)
      end unless user_tickets.blank?
    end
  end

end