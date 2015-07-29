module Helpdesk
  class ResetGroup < BaseWorker

    sidekiq_options :queue => :reset_group, :retry => 0, :backtrace => true, :failures => :exhausted
    BATCH_LIMIT = 50

    def perform(args)
      begin
        args.symbolize_keys!
        account = Account.current
        group_id = args[:group_id]
        begin
          records_nullified = Helpdesk::Ticket.update_all( "group_id = NULL", ["account_id = ? and group_id = ?", account.id,group_id], {:limit => BATCH_LIMIT} )
        end while records_nullified == BATCH_LIMIT
      rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
      end
    end

  end
end
