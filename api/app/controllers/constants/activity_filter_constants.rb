module ActivityFilterConstants
  INDEX_FIELDS = %w(ticket_id limit since_id before_id).freeze
  PERMITTED_ARCHIVE_FIELDS = (INDEX_FIELDS + ApiConstants::PAGINATE_FIELDS).freeze
end.freeze
