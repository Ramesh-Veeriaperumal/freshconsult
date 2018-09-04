module Channel::V2::ConversationConstants

  REPLY_FIELDS = ConversationConstants::REPLY_FIELDS | %w(created_at updated_at import_id)
  CREATE_FIELDS = ConversationConstants::CREATE_FIELDS | %w(created_at updated_at import_id)
end
