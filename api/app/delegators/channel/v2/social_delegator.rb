module Channel::V2
  class SocialDelegator < ConversationBaseDelegator
    validate :twitter_handle_presence, on: :create

    def initialize(record, options = {})
      super(record, options)
      @twitter_handle_id = options[:twitter_handle_id]
    end

    def twitter_handle_presence
      if twitter_ticket?
        twitter_handle = Account.current.twitter_handles.where(id: @twitter_handle_id).first
        errors[:twitter_handle_id] << :invalid_twitter_handle unless twitter_handle
      end
    end

    def twitter_ticket?
      Account.current.helpdesk_sources.note_source_keys_by_token['twitter'] == source
    end
  end
end
