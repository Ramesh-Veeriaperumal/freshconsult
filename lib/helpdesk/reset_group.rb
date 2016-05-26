module Helpdesk
  class ResetGroup < BaseWorker

    sidekiq_options :queue => :reset_group, :retry => 0, :backtrace => true, :failures => :exhausted
    BATCH_LIMIT = 50

    def perform(args)
      begin
        args.symbolize_keys!
        account = Account.current
        group_id = args[:group_id]

        account.tickets.where(group_id: group_id).update_all_with_publish({ group_id: nil }, {})

        return unless account.features?(:archive_tickets)

        account.archive_tickets.where(group_id: group_id).update_all_with_publish({ group_id: nil }, {})

      rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
      end
    end

  end
end
