module Tickets
  class UpdateTicketStatesWorker

    include Sidekiq::Worker
    include Redis::RedisKeys
    include Redis::OthersRedis

    sidekiq_options :queue => :update_ticket_states,
                    :retry => 0,
                    :backtrace => true,
                    :failures => :exhausted

    def perform(args)
      args.symbolize_keys!
      begin
        account = Account.current
        User.current = account.users.find_by_id args[:current_user_id]
        note = account.notes.find_by_id args[:id]
        return if note.blank?
        note.save_response_time unless note.private?
      rescue => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
        raise
      ensure
        note.trigger_observer(args[:model_changes]) unless args[:freshdesk_webhook]
      end
    end
  end
end
