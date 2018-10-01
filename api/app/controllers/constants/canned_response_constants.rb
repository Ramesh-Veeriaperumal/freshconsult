module CannedResponseConstants
  SEARCH_FIELDS = %w(ticket_id search_string).freeze
  SHOW_FIELDS = %w(include ticket_id).freeze
  ALLOWED_INCLUDE_PARAMS = %w(evaluated_response).freeze
  LOAD_OBJECT_EXCEPT = [:folder_responses].freeze
end.freeze
