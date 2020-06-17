module Channel::V2::ConversationConstants

  SOCIAL_ATTRIBUTES = %w[source_additional_info].freeze
  SOURCE_FIELD = %w[source].freeze
  NOTE_ATTRIBUTES = %w[created_at updated_at import_id].freeze
  REPLY_FIELDS = ConversationConstants::REPLY_FIELDS + NOTE_ATTRIBUTES
  CREATE_FIELDS = (ConversationConstants::CREATE_FIELDS + SOURCE_FIELD + SOCIAL_ATTRIBUTES + NOTE_ATTRIBUTES).freeze
  TWITTER_MSG_TYPES = ['dm', 'mention'].freeze
  CHANNEL_UPDATE_ATTRIBUTES = %w[private incoming user_id].freeze
  UPDATE_FIELDS = (ConversationConstants::UPDATE_FIELDS + NOTE_ATTRIBUTES + CHANNEL_UPDATE_ATTRIBUTES).freeze
end
