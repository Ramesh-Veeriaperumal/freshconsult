module ApiIntegrations
  module CtiConstants
    SCREEN_POP_FIELDS = %w(requester_id requester_phone requester_unique_external_id requester_email responder_id responder_phone responder_unique_external_id responder_email call_reference_id ticket_id new_ticket call_url)
    EXCLUDE_FIELDS = [:ticket_id, :requester_phone, :responder_phone, :requester_unique_external_id, :requester_email, :responder_unique_external_id, :responder_email, :call_info, :new_ticket, :call_url]
    INDEX_FIELDS = %w(call_reference_id).freeze
    RENAME_ERROR_FIELDS = { requester: :requester_id, responder: :responder_id }.freeze
    FEATURE_NAME = 'cti'.freeze
  end
end
