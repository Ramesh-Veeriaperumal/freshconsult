module Helpdesk
  class ResetGroup < BaseWorker

    sidekiq_options :queue => :reset_group, :retry => 0, :backtrace => true, :failures => :exhausted
    BATCH_LIMIT = 50

    def perform(args)
      begin
        args.symbolize_keys!
        account = Account.current
        group_id = args[:group_id]

        account.tickets.where(group_id: group_id).select(:id).find_in_batches(batch_size: BATCH_LIMIT) do |tickets|
          ticket_ids = tickets.map(&:id)
          account.tickets.where(id: ticket_ids).update_all(group_id: nil)
        end

        return unless account.features?(:archive_tickets)

        account.archive_tickets.where(group_id: group_id).select(:id).find_in_batches(batch_size: BATCH_LIMIT) do |tickets|
          ticket_ids = tickets.map(&:id)
          account.archive_tickets.where(id: ticket_ids).update_all(group_id: nil)          
        end

      rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
      end
    end

  end
end
