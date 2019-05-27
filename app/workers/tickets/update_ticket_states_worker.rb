module Tickets
  class UpdateTicketStatesWorker

    include Sidekiq::Worker
    include Redis::RedisKeys
    include Redis::OthersRedis

    sidekiq_options :queue => :update_ticket_states,
                    :retry => 0,
                    :backtrace => true,
                    :failures => :exhausted

    NOTE_ERROR = 'SAVE_NOTE_ERROR'.freeze

    def perform(args)
      args.symbolize_keys!
      begin
        account = Account.current
        User.current = account.users.find_by_id args[:current_user_id]
        @note = account.notes.find_by_id args[:id]
        Va::Logger::Automation.set_thread_variables(account.id, @note.try(:notable_id), args[:current_user_id])
        if @note.blank?
          Va::Logger::Automation.log("Observer not triggered, since the note is not present, info=#{args.inspect}", true)
          return
        end
        @note.save_response_time if should_save_response_time?
      rescue => e
        Va::Logger::Automation.log_error(NOTE_ERROR, e, args)
        NewRelic::Agent.notice_error(e, {:args => args})
        raise
      ensure
        return if @note.blank?
        inline = args[:send_and_set] ? true : false
        @note.trigger_observer(args[:model_changes], inline, false) unless args[:freshdesk_webhook]
        Va::Logger::Automation.unset_thread_variables
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
