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
        @note = account.notes.find_by_id args[:id]
        return if @note.blank?
        @note.save_response_time if should_save_response_time?
      rescue => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
        raise
      ensure
        return if @note.blank?
        inline = false
        system_event = false
        if args[:send_and_set]
          User.reset_current_user
          inline = true
          system_event = true
        end          
        @note.trigger_observer(args[:model_changes], inline, system_event ) unless args[:freshdesk_webhook]
      end
    end

    private
      def should_save_response_time?
        return true unless @note.private?
        @note.incoming? && note_from_social?
      end

      def note_from_social?
        @note.source.eql?(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"]) || 
          @note.source.eql?(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["twitter"])
      end
  end
end
