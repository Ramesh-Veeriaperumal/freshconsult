# frozen_string_literal: true

module Channel::V2::ConversationConstants
  SOCIAL_ATTRIBUTES = %w[source_additional_info].freeze
  SOURCE_FIELD = %w[source].freeze
  NOTE_ATTRIBUTES = %w[created_at updated_at import_id].freeze
  REPLY_FIELDS = ConversationConstants::REPLY_FIELDS + NOTE_ATTRIBUTES
  CREATE_FIELDS = (ConversationConstants::CREATE_FIELDS + SOURCE_FIELD + SOCIAL_ATTRIBUTES + NOTE_ATTRIBUTES).freeze
  TWITTER_MSG_TYPES = ['dm', 'mention'].freeze
  CHANNEL_UPDATE_ATTRIBUTES = %w[private incoming user_id].freeze
  UPDATE_FIELDS = (ConversationConstants::UPDATE_FIELDS + NOTE_ATTRIBUTES + CHANNEL_UPDATE_ATTRIBUTES).freeze
  LOAD_OBJECT_EXCEPT = ['sync'].freeze
  SYNC_DATETIME_ATTRIBUTES = %w[created_at].freeze
  SYNC_ARRAY_ATTRIBUTES = %w[user_ids ticket_ids].freeze
  SYNC_FILTER_ATTRIBUTES = (SYNC_DATETIME_ATTRIBUTES + SYNC_ARRAY_ATTRIBUTES).freeze
  SYNC_FIELDS = (%w[meta primary_key_offset] + SYNC_FILTER_ATTRIBUTES).freeze
  SYNC_ATTRIBUTE_MAPPING = {
    'created_at' => 'created_at',
    'user_ids' => 'user_id',
    'ticket_ids' => 'notable_id'
  }.freeze
end
