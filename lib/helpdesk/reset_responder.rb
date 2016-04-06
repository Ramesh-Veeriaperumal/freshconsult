module Helpdesk
  class ResetResponder < BaseWorker

    sidekiq_options :queue => :reset_responder, :retry => 0, :backtrace => true, :failures => :exhausted
    BATCH_LIMIT = 50

    def perform(args)
      begin
        args.symbolize_keys!
        account = Account.current
        user_id = args[:user_id]
        user = account.all_users.find_by_id(user_id)
        return if user.nil?
        
        account.tickets.where(responder_id: user.id).select(:id).find_in_batches(batch_size: BATCH_LIMIT) do |tickets|
          ticket_ids = tickets.map(&:id)
          account.tickets.where(id: ticket_ids).update_all(responder_id: nil)
        end

        return unless account.features?(:archive_tickets)

        account.archive_tickets.where(responder_id: user.id).select(:id).find_in_batches(batch_size: BATCH_LIMIT) do |tickets|
          ticket_ids = tickets.map(&:id)
          account.archive_tickets.where(id: ticket_ids).update_all(responder_id: nil)
        end

      rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
      end
    end

  end
end