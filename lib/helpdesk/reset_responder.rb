module Helpdesk
  class ResetResponder < BaseWorker

    sidekiq_options :queue => :reset_responder, :retry => 0, :backtrace => true, :failures => :exhausted
    BATCH_LIMIT = 500

    def perform(args)
      begin
        args.symbolize_keys!
        account = Account.current
        user_id = args[:user_id]
        user = account.all_users.find_by_id(user_id)
        return if user.nil?
        begin
          records_nullified = Helpdesk::Ticket.update_all( "responder_id = NULL", ["account_id = ? and responder_id = ?", account.id,user.id], {:limit => BATCH_LIMIT} )
        end while records_nullified == BATCH_LIMIT
      rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
      end
    end

  end
end
