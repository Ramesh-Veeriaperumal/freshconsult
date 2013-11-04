class Workers::BulkReplyTickets
  extend Resque::AroundPerform 
  @queue = 'bulk_reply_tickets'

  def self.perform(params)

    performer = Helpdesk::BulkReplyTickets.new(params)
    performer.act
    performer.cleanup!
  end

end