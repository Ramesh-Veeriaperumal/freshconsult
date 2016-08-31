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

        account.tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {})
        if account.features?(:shared_ownership)
          internal_agent_col = Helpdesk::SchemaLessTicket.internal_agent_column
          account.schema_less_tickets.where(internal_agent_col => user.id).update_all_with_publish({internal_agent_col => nil }, {})
        end

        return unless account.features_included?(:archive_tickets)

        account.archive_tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {})

      rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
      end
    end

  end
end