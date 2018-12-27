module CannedResponseConstants
  SEARCH_FIELDS = %w(ticket_id search_string folder_id).freeze
  SHOW_FIELDS = %w(include ticket_id).freeze
  ALLOWED_INCLUDE_PARAMS = %w(evaluated_response).freeze
  CREATE_FIELDS = %w(title content_html folder_id visibility group_ids attachments attachment_ids).freeze
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form]
  }.freeze
  LOAD_OBJECT_EXCEPT = [:folder_responses].freeze
  DELEGATE_FIELDS= %w(folder_id visibility group_ids attachment_ids).freeze
  WRAP_PARAMS = [:canned_response, exclude: [], format: [:json, :multipart_form]].freeze
end.freeze
