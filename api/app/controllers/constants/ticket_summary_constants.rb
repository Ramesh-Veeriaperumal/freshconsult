module TicketSummaryConstants
  UPDATE_ARRAY_FIELDS = %w(attachments attachment_ids).freeze
  UPDATE_FIELDS = %w(body user_id).freeze | UPDATE_ARRAY_FIELDS | AttachmentConstants::CLOUD_FILE_FIELDS
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    update: %i(json multipart_form)
  }.freeze
  PARAMS_TO_SAVE_AND_REMOVE = [:cloud_files, :attachment_ids].freeze
  PARAMS_TO_REMOVE = [:body].freeze
  WRAP_PARAMS = [:ticket_summary, exclude: [], format: [:json, :multipart_form]].freeze
  ERROR_FIELD_MAPPINGS = { notable_id: :ticket_id, user: :user_id }.freeze
  DELEGATOR_CLASS = 'TicketSummaryDelegator'.freeze
end.freeze
